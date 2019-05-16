Puppet::Functions.create_function :'conjur::token' do
  dispatch :from_key do
    param 'Conjur::Endpoint', :client
    param 'String[1]', :login
    param 'Sensitive[String[1]]', :key
    optional_param 'Optional[String]', :account
    return_type 'Sensitive'
  end

  def from_key client, login, key, account
    key = key.unwrap
    Puppet::Pops::Types::PSensitiveType::Sensitive.new client.authenticate login, key, account
  end
end
