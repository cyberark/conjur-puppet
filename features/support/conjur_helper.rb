require 'conjur-api'
require 'openssl'
require 'socket'

module ConjurHelper
  def load_integration_policy
    return if $policy_loaded

    conjur_client.load_policy('root', policy, method: :put)

    conjur_client.resource('puppet:variable:secrets/a').add_value secret_a
    conjur_client.resource('puppet:variable:secrets/b').add_value secret_b

    $policy_loaded = true
  end

  def secret_a
    $secret_a ||= "A secret (#{SecureRandom.hex})"
  end

  def secret_b
    $secret_b ||= "B secret (#{SecureRandom.hex})"
  end

  def conjur_value(variable_id)
    conjur_client.resource("puppet:variable:#{variable_id}").value
  end

  def preconfigured_apikey
    $preconfigured_apikey ||= conjur_client.resource('puppet:host:preconfigured_host').rotate_api_key
  end

  def appliance_url
    @appliance_url ||= "https://#{appliance_hostname}"
  end

  def appliance_hostname
    @appliance_hostname ||= Util::Terraform.output('conjur_master_public').strip
  end

  def conjur_ca_certificate
    @conjur_ca_certificate ||= ConjurHelper.get_certificate(appliance_hostname)[1]
  end

  private

  def policy
    File.read('ci/policy/root.yml')
  end

  def conjur_client
    @conjur_client ||= begin
      Conjur.configuration.account = 'puppet'
      Conjur.configuration.appliance_url = appliance_url
      Conjur.configuration.version = 5

      cert_file = Tempfile.new("conjur_cert")
      File.write(cert_file.path, conjur_ca_certificate)

      OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.fix_broken_httpclient
      OpenSSL::SSL::SSLContext::DEFAULT_CERT_STORE.add_file(cert_file.path)
      OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers] = OpenSSL::SSL::SSLContext.new.ciphers

      Conjur::API.new_from_key 'admin', api_key
    end
  end

  def host_factory_token
    @host_factory_token ||= begin
      expiration = 1.day.from_now
      conjur_client.resource('puppet:host_factory:puppet')
                   .create_token(expiration)
                   .token
    end
  end

  def api_key
    @api_key ||= Conjur::API.login('admin', password)
  end

  def password
    @password ||= Util::Terraform.output('conjur_master_password').strip
  end

  def self.get_certificate(connect_hostname)
    include OpenSSL::SSL

    host, port = connect_hostname.split ':'
    port ||= 443

    sock = TCPSocket.new host, port.to_i
    ssock = SSLSocket.new sock
    ssock.hostname = host
    ssock.connect
    chain = ssock.peer_cert_chain
    cert = chain.first
    fp = Digest::SHA1.digest cert.to_der

    # convert to hex, then split into bytes with :
    hexfp = (fp.unpack 'H*').first.upcase.scan(/../).join(':')

    ["SHA1 Fingerprint=#{hexfp}", chain.map(&:to_pem).join]
  ensure
    ssock.close if ssock
    sock.close if sock
  end

  # 'httpclient' monkey patches OpenSSL::X509::Store to store certificates
  # in its own `@_httpclient_cert_store_items` variable. The default store,
  # however, does not get properly initialized leading to `undefined method
  # `<<' for nil:NilClass` when calling `#add_file`.
  #
  # This module allows us to initialize the variable so the default store
  # works as expected.
  module ::OpenSSL
    module X509
      class Store
        def fix_broken_httpclient
          @_httpclient_cert_store_items = [ENV['SSL_CERT_FILE'] || :default]
        end
      end
    end
  end
end

World(ConjurHelper)
