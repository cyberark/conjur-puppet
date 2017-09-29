Puppet::Functions.create_function :'conjur::token' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :from_key do
    param 'Conjur::Endpoint', :client
    param 'String', :login
    param sensitive.name.split("::").last, :key
    optional_param 'String', :account
  end

  dispatch :from_key do
    param 'Conjur::Endpoint', :client
    param 'String', :login
    param sensitive.name.split("::").last, :key
    optional_param 'Undef', :_
  end

  def from_key client, login, key, account
    key = key.unwrap if key.respond_to? :unwrap
    sensitive.new client.authenticate login, key, account
  end
end
