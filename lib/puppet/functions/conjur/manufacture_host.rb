Puppet::Functions.create_function :'conjur::manufacture_host' do
  dispatch :create do
    param 'Conjur::Endpoint', :client
    param 'String', :id
    param 'String', :token
  end

  def create client, hostid, token
    client.create_host hostid, token, annotations: { puppet: true }
  end
end
