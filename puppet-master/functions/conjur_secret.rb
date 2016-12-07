Puppet::Functions.create_function(:'conjur_secret') do
  def conjur_secret variable_id
    require 'base64'
    require 'openssl'

    conjur_token_ctxt = closure_scope.lookupvar('conjur_token') or raise "No conjur_token fact is available"
    conjur_token_ctxt = Base64.decode64(conjur_token_ctxt)
    certdir = Puppet.settings[:certdir]
    privatekeydir = Puppet.settings[:privatekeydir]
    hostname = Puppet.settings[:server] #`puppet config print certname`.strip
    cert_pem = File.read(File.join(certdir, "#{hostname}.pem"))
    key_pem = File.read(File.join(privatekeydir, "#{hostname}.pem"))
    key = OpenSSL::PKey.read(key_pem)
    certificate = OpenSSL::X509::Certificate.new(cert_pem)
    decryptor = OpenSSL::PKCS7.new(conjur_token_ctxt)
    conjur_token = decryptor.decrypt(key, certificate)
    conjur_token = JSON.parse(conjur_token)

    # Should probably store these in a custom YAML config file, since ENV is not visible inside Puppet (at least, not as ENV)
    require 'conjur-api'
    Conjur.configuration.appliance_url = Puppet[:conjur_url] || ENV['CONJUR_APPLIANCE_URL'] || "https://conjur/api"
    Conjur.configuration.account = Puppet[:conjur_account] || ENV['CONJUR_ACCOUNT'] || "cucumber"
    Conjur.configuration.cert_file = Puppet[:conjur_cert_file] || ENV['CONJUR_CERT_FILE'] || "/etc/conjur.pem"
    Conjur.configuration.apply_cert_config!

    conjur_api = Conjur::API.new_from_token conjur_token
    conjur_api.variable(variable_id).value
  end
end
