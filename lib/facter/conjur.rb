Facter.add :conjur do
  setcode do
    def config
      @config ||= if File.exist? '/etc/conjur.conf'
        c = YAML.load File.read '/etc/conjur.conf'
        c['ssl_certificate'] ||= File.read c['cert_file'] \
            if c['cert_file']
        c
      else
        {}
      end
    end

    def credentials netrc_path, url
      uri = URI.parse url
      File.open netrc_path do |netrc|
        found = login = password = nil
        netrc.each_line do |line|
          key, value, _ = line.split
          case key
          when 'machine'
            found = value.start_with?(uri.to_s) || value == uri.host
          when 'login'
            login = value if found
          when 'password'
            password = value if found
          end
          return [login, password] if login && password
        end
      end
    end

    def find_certs certs
      cert_header = '-----BEGIN CERTIFICATE-----'.freeze
      cert_footer = '-----END CERTIFICATE-----'.freeze
      cert_re = /#{cert_header}\r?\n.*?\r?\n#{cert_footer}/m.freeze

      certs.scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
    end

    def cert_store certs
      OpenSSL::X509::Store.new.tap do |store|
        find_certs(certs).each &store.method(:add_cert)
      end
    end

    def authenticate url, certs, credentials
      login, key = credentials
      uri = URI(url + '/') + "authn/users/#{URI.encode_www_form_component(login)}/authenticate"
      Net::HTTP.start uri.host, uri.port, use_ssl: uri.scheme == 'https', cert_store: cert_store(certs) do |http|
        response = http.post uri.request_uri, key
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end
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

    def puppet_certificate
      @puppet_certificate ||= begin
        itc = Puppet::Resource::Catalog.indirection.terminus.class
        get_ssl_cert itc.server, itc.port,
            Puppet::SSL::Validator.default_validator.ssl_configuration.ca_chain_file
      end
    end

    def encrypt_for_master data
      cipher_name = 'AES-256-CBC'
      cipher = OpenSSL::Cipher::Cipher.new(cipher_name)
      encryptor = OpenSSL::PKCS7.encrypt([ puppet_certificate ], data, cipher, OpenSSL::PKCS7::BINARY)
      encryptor.to_pem
    end

    def standalone?
      # HACK is there a better way to detect if this is puppet apply?
      Puppet[:catalog_terminus] == :compiler
    end

    begin
      netrc_path = config['netrc_path'] || '/etc/conjur.identity'
      if url = config['appliance_url']
        creds = credentials netrc_path, url
        config['authn_login'] = creds.first
        token = authenticate url, config['ssl_certificate'], creds
        if standalone?
          config['token'] = token
        else
          config['encrypted_token'] = encrypt_for_master token
        end
      end
    rescue
      # if there's an error at least try to return the config
      warn $!
    end

    config
  end
end
