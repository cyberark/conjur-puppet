Puppet::Functions.create_function :'conjur::manufacture_host' do
  dispatch :create do
    param 'String', :url
    param 'String', :id
    param 'String', :token
  end

  def create url, hostid, token
    client = call_function 'conjur::client', url, closure_scope['conjur::ssl_certificate']
    client.create_host hostid, token, annotations: { puppet: true }
  end
end
