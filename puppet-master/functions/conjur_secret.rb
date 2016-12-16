Puppet::Functions.create_function(:'conjur_secret') do
  def configure_conjur
    conjur_config = Puppet.settings[:conjur_config] || File.join(Puppet.settings[:confdir], 'conjur.yaml')
    if Puppet::FileSystem.exist?(conjur_config)
      config = YAML.load(File.read(conjur_config))
      require 'conjur-api'
      Conjur.configuration.appliance_url = config['appliance_url'] or raise "Conjur url is required in conjur.yml"
      Conjur.configuration.account = config['account'] or raise "Conjur account is required in conjur.yml"
      if Conjur.configuration.cert_file.nil? && cert_file = config['cert_file']
        Conjur.configuration.cert_file = cert_file
        Conjur.configuration.apply_cert_config!
      end
    else
      raise "Conjur config file #{conjur_config} not found"
    end
  end

  def conjur_secret variable_id
    require 'base64'
    require 'openssl'

    configure_conjur

    conjur_token_ctxt = closure_scope.lookupvar('conjur_token') or raise "No conjur_token fact is available"
    conjur_token_ctxt = Base64.decode64(conjur_token_ctxt)
    host = Puppet::SSL::Host.localhost
    key = host.key.content
    certificate = host.certificate.content
    decryptor = OpenSSL::PKCS7.new(conjur_token_ctxt)
    conjur_token = decryptor.decrypt(key, certificate)
    conjur_token = JSON.parse(conjur_token)

    conjur_api = Conjur::API.new_from_token conjur_token
    conjur_api.variable(variable_id).value
  end
end
