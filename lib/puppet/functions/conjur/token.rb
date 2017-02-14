Puppet::Functions.create_function :'conjur::token' do
  dispatch :from_key do
    param 'String', :url
    param 'String', :login
    param 'String', :key
  end

  def from_key url, login, key
    client = call_function 'conjur::client', url, closure_scope['conjur::ssl_certificate']
    client.authenticate login, key
  end
end
