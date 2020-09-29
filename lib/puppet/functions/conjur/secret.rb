# frozen_string_literal: true

require 'conjur/puppet_module/config'
require 'conjur/puppet_module/http'
require 'conjur/puppet_module/identity'

# Function to retrieve a Conjur / DAP secret
Puppet::Functions.create_function :'conjur::secret' do
  # @param variable_id Conjur / DAP variable ID that you want the value of.
  # @param options Optional parameter specifying server identity overrides
  #   The following keys are supported in the options hash:
  #   - appliance_url: The URL of the Conjur or DAP instance..
  #   - account: Name of the Conjur account that contains this variable.
  #   - authn_login: The identity you are using to authenticate to the Conjur / DAP instance.
  #   - authn_api_key: The API key of the identity you are using to authenticate with (must be Sensitive type).
  #   - cert_file: The absolute path to CA certificate chain for the DAP instance on the agent. This variable overrides `ssl_certificate`.
  #   - ssl_certificate: The _raw_ PEM-encoded x509 CA certificate chain for the DAP instance. Overwritten by the contents read from `cert_file` when it is present.
  #   - version: Conjur API version, defaults to 5.
  # @return [Sensitive] Value of the Conjur variable.
  # @example Agent-based identity invocation
  #   Deferred(conjur::secret, ['production/postgres/password'])
  # @example Server-based identity invocation
  #   $sslcert = @("EOT")
  #   -----BEGIN CERTIFICATE-----
  #   ...
  #   -----END CERTIFICATE-----
  #   |-EOT
  #
  #   $dbpass = Deferred(conjur::secret, ['production/postgres/password', {
  #     appliance_url => "https://my.conjur.org",
  #     account => "myaccount",
  #     authn_login => "host/myhost",
  #     authn_api_key => Sensitive("2z9mndg1950gcx1mcrs6w18bwnp028dqkmc34vj8gh2p500ny1qk8n"),
  #     ssl_certificate => $sslcert
  #   }])
  dispatch :with_credentials do
    required_param 'String', :variable_id
    optional_param 'Hash', :options

    return_type 'Sensitive'
  end

  def authentication_path(account, login)
    ['authn', account, login, 'authenticate']
      .map(&URI.method(:encode_www_form_component)).join('/')
  end

  # Authenticates against a Conjur / DAP server returning the API token
  def authenticate(url, ssl_certificate, account, authn_login, authn_api_key)
    Conjur::PuppetModule::HTTP.post(
      url,
      authentication_path(account, authn_login),
      ssl_certificate,
      authn_api_key.unwrap,
    )
  end

  # Fetches a variable from Conjur / DAP
  def get_variable(url, ssl_certificate, account, variable_id, token)
    secrets_path = [
      'secrets',
      URI.encode_www_form_component(account),
      'variable',
      ERB::Util.url_encode(variable_id),
    ].join('/')

    Conjur::PuppetModule::HTTP.get(
      url,
      secrets_path,
      ssl_certificate,
      token,
    )
  end

  def with_credentials(id, options = {})
    # If we got an options hash, it may be frozen so we make a copy that is not since
    # we will be modifying it
    opts = options.dup

    if opts['authn_api_key']
      raise "Value of 'authn_api_key' must be wrapped in 'Sensitive()'!" \
        unless opts['authn_api_key'].is_a? Puppet::Pops::Types::PSensitiveType::Sensitive
    end

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

    # If cert_file is set, use it to override ssl_certificate
    if opts['cert_file']
      raise "Cert file '#{opts['cert_file']}' cannot be found!" unless File.file?(opts['cert_file'])
      opts['ssl_certificate'] = File.read opts['cert_file']
    end

    Puppet.debug('Instantiating Conjur client...')
    Puppet.debug('Fetching Conjur token')
    token = authenticate(opts['appliance_url'], opts['ssl_certificate'], opts['account'],
                         opts['authn_login'], opts['authn_api_key'])
    Puppet.info('Conjur token retrieved')

    Puppet.debug("Fetching Conjur secret '#{id}'...")
    secret = get_variable(opts['appliance_url'], opts['ssl_certificate'], opts['account'],
                          id, token)
    Puppet.info("Conjur secret #{id} retrieved")

    Puppet::Pops::Types::PSensitiveType::Sensitive.new(secret)
  end
end
