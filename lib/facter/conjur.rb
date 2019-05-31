# frozen_string_literal: true

require 'conjur/puppet_module/config'
require 'conjur/puppet_module/identity'

Facter.add :conjur do
  setcode do
    def config
      @config ||= Conjur::PuppetModule::Config.load
    end

    def find_certs certs
      cert_header = '-----BEGIN CERTIFICATE-----'.freeze
      cert_footer = '-----END CERTIFICATE-----'.freeze
      cert_re = /#{cert_header}\r?\n.*?\r?\n#{cert_footer}/m.freeze

      certs.scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
    end

    def cert_store certs
      certs && OpenSSL::X509::Store.new.tap do |store|
        find_certs(certs).each &store.method(:add_cert)
      end
    end

    def authentication_path login
      account = case version
        when 5
          config['account'] or raise ArgumentError, "account is required for v5"
        else
          'users'
        end
      ['authn', account, login, 'authenticate'].
          map(&URI.method(:encode_www_form_component)).join('/')
    end

    def version
      @version ||= config['version'] || 4
    end

    # A common mistake is to omit the trailing slash in an uri.
    # Conjur API is always at a directory level, so make sure it's right.
    def directory_uri url
      url += '/' unless url.end_with? '/'
      URI url
    end

    def authenticate url, certs, credentials
      login, key = credentials
      uri = directory_uri(url) + authentication_path(login)
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
      cipher = OpenSSL::Cipher.new(cipher_name)
      encryptor = OpenSSL::PKCS7.encrypt([ puppet_certificate ], data, cipher, OpenSSL::PKCS7::BINARY)
      encryptor.to_pem
    end

    def standalone?
      # HACK is there a better way to detect if this is puppet apply?
      Puppet[:catalog_terminus] == :compiler
    end

    begin
      if (url = config['appliance_url'])
        creds = Conjur::PuppetModule::Identity.load(config)
        raise 'Conjur identity not found on system' unless creds

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
