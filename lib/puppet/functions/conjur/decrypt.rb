# Decrypt PKCS7 boxed data with our own puppet host certificate
Puppet::Functions.create_function :'conjur::decrypt' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :decrypt do
    param 'String', :pkcs7
  end

  def decrypt pkcs7
    host = Puppet::SSL::Host.localhost
    key = host.key.content
    certificate = host.certificate.content
    decryptor = OpenSSL::PKCS7.new pkcs7
    sensitive.new decryptor.decrypt key, certificate
  end
end
