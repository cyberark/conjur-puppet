# frozen_string_literal: true

require 'conjur/puppet_module/config'
require 'conjur/puppet_module/identity'

# Function to retrieve a Conjur / DAP secret
Puppet::Functions.create_function :'conjur::secret' do
  # @param variable_id Conjur / DAP variable ID that you want the value of.
  # @param appliance_url The URL of the Conjur or DAP instance..
  # @param account Name of the Conjur account that contains this variable.
  # @param authn_login The identity you are using to authenticate to the Conjur / DAP instance.
  # @param authn_api_key The API key of the identity you are using to authenticate with.
  # @param ssl_certificate The _raw_ PEM-encoded x509 CA certificate chain for the DAP instance.
  # @param version Conjur API version, defaults to 5.
  # @return [Sensitive] Value of the Conjur variable.
  # @example Agent-based identity invocation
  #   Sensitive(Deferred(conjur::secret, ['production/postgres/password']))
  # @example Server-based identity invocation
  #   $sslcert = @("EOT")
  #   -----BEGIN CERTIFICATE-----
  #   ...
  #   -----END CERTIFICATE-----
  #   |-EOT
  #   
  #   $dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password',
  #     "https://my.conjur.org",
  #     "myaccount",
  #     "host/myhost",
  #     Sensitive("2z9mndg1950gcx1mcrs6w18bwnp028dqkmc34vj8gh2p500ny1qk8n"),
  #     $sslcert
  #   ]))
  dispatch :with_credentials do
    param 'String', :variable_id
    optional_param 'String', :appliance_url
    optional_param 'String', :account
    optional_param 'String', :authn_login
    optional_param 'Sensitive', :authn_api_key
    optional_param 'String', :ssl_certificate
    optional_param 'String', :version

    return_type 'Sensitive'
  end

  def find_certs certs
    cert_header = '-----BEGIN CERTIFICATE-----'
    cert_footer = '-----END CERTIFICATE-----'
    cert_re = /#{cert_header}\r?\n.*?\r?\n#{cert_footer}/m

    certs.scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
  end

  def cert_store certs
    certs && OpenSSL::X509::Store.new.tap do |store|
      find_certs(certs).each &store.method(:add_cert)
    end
  end

  def authentication_path account, login
    ['authn', account, login, 'authenticate'].
          map(&URI.method(:encode_www_form_component)).join('/')
  end

  def directory_uri url
    url += '/' unless url.end_with? '/'
    URI url
  end

  # Authenticates against a Conjur / DAP server returning the API token
  def authenticate url, account, authn_login, authn_api_key, ssl_certificate
    uri = directory_uri(url) + authentication_path(account, authn_login)
    use_ssl = uri.scheme == 'https'

    Net::HTTP.start uri.host, uri.port, use_ssl: use_ssl, cert_store: cert_store(ssl_certificate) do |http|
      response = http.post uri.request_uri, authn_api_key.unwrap
      raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
      response.body
    end
  end

  def get_token appliance_url, account, authn_login, authn_api_key, ssl_certificate
    authenticate(appliance_url, account, authn_login, authn_api_key, ssl_certificate)
  end

  def with_credentials id, appliance_url = nil, account = nil, authn_login = nil,
    authn_api_key = nil, ssl_certificate = nil, version = 5

    # If we didn't get any config from the server, assume it's on the agent
    if appliance_url.nil? || appliance_url.empty?
      config = Conjur::PuppetModule::Config.load
      raise 'Conjur configuration not found on system' if config.empty?

      creds = Conjur::PuppetModule::Identity.load(config)
      raise 'Conjur identity not found on system' unless creds

      appliance_url = config['appliance_url']
      account = config['account']
      ssl_certificate = config['ssl_certificate']
      version = config['version']

      authn_login, authn_api_key = creds
      authn_api_key = Puppet::Pops::Types::PSensitiveType::Sensitive.new(authn_api_key)
    end

    # Ideally we would be able to support `cert_file` here too

    Puppet.debug("Instantiating Conjur client...")
    client = call_function('conjur::client', appliance_url, version, ssl_certificate)

    Puppet.debug("Fetching Conjur token")
    token = get_token(appliance_url, account, authn_login, authn_api_key, ssl_certificate)
    Puppet.info("Conjur token retrieved")

    Puppet.debug("Fetching Conjur secret '#{id}'...")
    secret = client.variable_value(account, id, token)
    Puppet.info("Conjur secret #{id} retrieved")

    Puppet::Pops::Types::PSensitiveType::Sensitive.new(secret)
  end
end
