Facter.add('conjur_token') do
  setcode do
    require 'net/http'
    require 'openssl'
    require 'open-uri'
    require 'base64'
    require 'json'
    require 'conjur-cli'
    require 'restclient'

    def do_retry times, delay = 5, &block
      tries = 0
      begin
        yield
      rescue
        sleep delay
        if ( tries += 1 ) < times
          retry
        else
          raise
        end
      end
    end

    Conjur::Config.load
    Conjur::Config.apply
    conjur_api = Conjur::Authn.connect nil, noask: true

    token = do_retry 3 do
      JSON.pretty_generate(conjur_api.token)
    end

    #ca_file = '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
    #https_options = if File.exists?(ca_file)
    #  OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_file ca_file
    #  { ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER }
    #else
    https_options =  { ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE }
    #end

    puppet_hostname = Puppet.settings[:server] # `puppet config print server`.strip
    ca_hostname = Puppet.settings[:ca_server] # puppet config print ca_server`.strip
    ca_port = Puppet.settings[:ca_port] # `puppet config print ca_port`.strip

    # Get the certificate of the Puppet master
    uri = URI.parse("https://#{ca_hostname}:#{ca_port}/puppet-ca/v1/certificate/#{puppet_hostname}?environment=_")
    puppet_cert_pem = uri.open(https_options).readlines.join

    cipher_name = 'AES-256-CBC'
    puppet_certificate = OpenSSL::X509::Certificate.new puppet_cert_pem
    cipher = OpenSSL::Cipher::Cipher.new(cipher_name)

    encryptor = OpenSSL::PKCS7.encrypt([ puppet_certificate ], token, cipher, OpenSSL::PKCS7::BINARY)
    Base64.strict_encode64 encryptor.to_pem
  end
end
