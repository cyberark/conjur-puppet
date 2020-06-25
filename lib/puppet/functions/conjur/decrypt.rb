# Decrypt PKCS7 boxed data with our own puppet host certificate
Puppet::Functions.create_function :'conjur::decrypt' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :decrypt do
    param 'String', :pkcs7
  end

  def decrypt pkcs7
    certificate = nil
    key = nil

    # Use Puppet 6+ extraction of cert and key if we can otherwise fall
    # back to v5 methods
    if defined?(Puppet::X509) == 'constant'
      certificate_content = File.read(Puppet[:hostcert])
      certificate = OpenSSL::X509::Certificate.new(certificate_content)

      cert_provider = Puppet::X509::CertProvider.new
      key_content = cert_provider.load_private_key(Puppet[:certname])
      key = OpenSSL::PKey::RSA.new(key_content, '')
    else
      host = Puppet::SSL::Host.localhost
      certificate = host.certificate.content
      key = host.key.content
    end

    decryptor = OpenSSL::PKCS7.new pkcs7
    sensitive.new decryptor.decrypt key, certificate
  end
end
