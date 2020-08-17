# frozen_string_literal: true

require 'conjur/puppet_module/config'
require 'conjur/puppet_module/identity'

# Function to retrieve a Conjur / DAP secret
Puppet::Functions.create_function :'conjur::secret' do
  # @param variable_id Conjur / DAP variable ID that you want the value of.
  # @param options Optional parameter specifying server identity overrides
  #   The following keys are supported in the options hash:
  #   - appliance_url: The URL of the Conjur or DAP instance..
  #   - account: Name of the Conjur account that contains this variable.
  #   - authn_login: The identity you are using to authenticate to the Conjur / DAP instance.
  #   - authn_api_key: The API key of the identity you are using to authenticate with.
  #   - ssl_certificate: The _raw_ PEM-encoded x509 CA certificate chain for the DAP instance.
  #   - version: Conjur API version, defaults to 5.
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
  #   $dbpass = Sensitive(Deferred(conjur::secret, ['production/postgres/password', {
  #     appliance_url => "https://my.conjur.org",
  #     account => "myaccount",
  #     authn_login => "host/myhost",
  #     authn_api_key => Sensitive("2z9mndg1950gcx1mcrs6w18bwnp028dqkmc34vj8gh2p500ny1qk8n"),
  #     ssl_certificate => $sslcert
  #   }]))
  dispatch :with_credentials do
    required_param 'String', :variable_id
    optional_param 'Hash', :options

    return_type 'Sensitive'
  end

  def find_certs(certs)
    cert_header = '-----BEGIN CERTIFICATE-----'
    cert_footer = '-----END CERTIFICATE-----'
    cert_re = %r{#{cert_header}\r?\n.*?\r?\n#{cert_footer}}m

    certs.scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
  end

  def cert_store(certs)
    certs && OpenSSL::X509::Store.new.tap do |store|
      find_certs(certs).each(&store.method(:add_cert))
    end
  end

  def authentication_path(account, login)
    ['authn', account, login, 'authenticate']
      .map(&URI.method(:encode_www_form_component)).join('/')
  end

  def directory_uri(url)
    url += '/' unless url.end_with? '/'
    URI url
  end

  # Authenticates against a Conjur / DAP server returning the API token
  def authenticate(url, account, authn_login, authn_api_key, ssl_certificate)
    uri = directory_uri(url) + authentication_path(account, authn_login)
    use_ssl = uri.scheme == 'https'

    Net::HTTP.start uri.host, uri.port, use_ssl: use_ssl, cert_store: cert_store(ssl_certificate) do |http|
      response = http.post uri.request_uri, authn_api_key.unwrap
      raise Net::HTTPError.new response.message, response unless response.code.match?(%r{^2})
      response.body
    end
  end

  def get_token(appliance_url, account, authn_login, authn_api_key, ssl_certificate)
    authenticate(appliance_url, account, authn_login, authn_api_key, ssl_certificate)
  end

  def with_credentials(id, options = {})
    # If we got an options hash, it may be frozen so we make a copy that is not since
    # we will be modifying it
    opts = options.dup

    opts['version'] ||= 5

    # If we didn't get any config from the server, assume it's on the agent
    if opts['appliance_url'].nil? || opts['appliance_url'].empty?
      config = Conjur::PuppetModule::Config.load
      raise 'Conjur configuration not found on system' if config.empty?

      creds = Conjur::PuppetModule::Identity.load(config)
      raise 'Conjur identity not found on system' unless creds

      # Overwrite values in the options hash with the ones from the agent. We may at
      # some point want to support partial overwrite of only the set values.
      ['appliance_url', 'account', 'ssl_certificate', 'version'].each do |key|
        opts[key] = config[key]
      end

      opts['authn_login'], authn_api_key = creds
      opts['authn_api_key'] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(authn_api_key)
    end

    # Ideally we would be able to support `cert_file` here too

    Puppet.debug('Instantiating Conjur client...')
    client = call_function('conjur::client', opts['appliance_url'], opts['version'],
                           opts['ssl_certificate'])

    Puppet.debug('Fetching Conjur token')
    token = get_token(opts['appliance_url'], opts['account'], opts['authn_login'],
                      opts['authn_api_key'], opts['ssl_certificate'])
    Puppet.info('Conjur token retrieved')

    Puppet.debug("Fetching Conjur secret '#{id}'...")
    secret = client.variable_value(opts['account'], id, token)
    Puppet.info("Conjur secret #{id} retrieved")

    Puppet::Pops::Types::PSensitiveType::Sensitive.new(secret)
  end
end
