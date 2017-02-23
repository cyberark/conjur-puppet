Puppet::Functions.create_function :'conjur::token' do
  dispatch :from_key do
    param 'Conjur::Endpoint', :client
    param 'String', :login
    param 'String', :key
  end

  def from_key client, login, key
    client.authenticate login, key
  end
end
