Puppet::Functions.create_function :'conjur::netrc' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :netrc do
    param 'String', :appliance_url
    param 'String', :authn_login
    param sensitive.name.split("::").last, :api_key
  end

  def netrc url, login, key
    key = key.unwrap if key.respond_to? :unwrap
    url = URI(url) + 'authn'
    sensitive.new "machine #{url}\n  login #{login}\n  password #{key}"
  end
end
