Puppet::Functions.create_function :'conjur::token' do
  dispatch :from_key do
    param 'Conjur::Endpoint', :client
    param 'String', :login
    param 'Sensitive', :key
  end

  def from_key client, login, key
    Puppet::Pops::Types::PSensitiveType::Sensitive.new \
        client.authenticate login, key.unwrap
  end
end
