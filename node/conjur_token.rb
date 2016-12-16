Facter.add('conjur_token') do
  setcode do
    require 'yaml'
    require 'conjur-api'
    require 'net/http'
    require 'openssl'
    require 'open-uri'
    require 'json'
    require 'netrc'

    def configure_conjur
      conjur_config = Puppet.settings[:conjur_config] || File.join(Puppet.settings[:confdir], 'conjur.yaml')
      if Puppet::FileSystem.exist?(conjur_config)
        config = YAML.load(File.read(conjur_config))
        Conjur.configuration.appliance_url = config['appliance_url'] or raise "Conjur url is required in conjur.yml"
        Conjur.configuration.account = config['account'] or raise "Conjur account is required in conjur.yml"
        if Conjur.configuration.cert_file.nil? && ( cert_file = config['cert_file'] )
          Conjur.configuration.cert_file = cert_file
          Conjur.configuration.apply_cert_config!
        end
      else
        raise "Conjur config file #{conjur_config} not found"
      end
    end

    configure_conjur

    def do_retry times, delay = 5, &block
      tries = 0
      begin
        yield
      rescue
        puts $!.message
        sleep delay
        if ( tries += 1 ) < times
          retry
        else
          raise
        end
      end
    end

    netrc_file = ENV['CONJUR_NETRC_PATH'] || File.expand_path("~/.netrc")
    netrc = Netrc.read(netrc_file)
    credentials = netrc[[ Conjur.configuration.appliance_url, "authn" ].join("/")] or raise "No Conjur credentials found in netrc file"
    conjur_api = Conjur::API.new_from_key(*credentials)

    token = do_retry 3 do
      JSON.pretty_generate(conjur_api.token)
    end

    def get_ssl_cert host, port, ca_file
      context = OpenSSL::SSL::SSLContext.new
      context.verify_callback = Puppet::SSL::Validator.default_validator
      context.ca_file = ca_file
      sock = TCPSocket.new host, port
      client = OpenSSL::SSL::SSLSocket.new sock, context
      client.connect
      client.peer_cert
    ensure
      client.close if client
      sock.close if sock
    end

    cipher_name = 'AES-256-CBC'
    puppet_certificate = get_ssl_cert *%i(server masterport localcacert).map(&Puppet.method(:[]))
    cipher = OpenSSL::Cipher::Cipher.new(cipher_name)
    encryptor = OpenSSL::PKCS7.encrypt([ puppet_certificate ], token, cipher, OpenSSL::PKCS7::BINARY)
    Base64.strict_encode64 encryptor.to_pem
  end
end
