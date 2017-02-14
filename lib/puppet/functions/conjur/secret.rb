Puppet::Functions.create_function :'conjur::secret' do
  dispatch :secret do
    param 'String', :variable_id
  end

  def secret id
    scope = closure_scope
    client = call_function 'conjur::client', scope['conjur::appliance_url'], scope['conjur::ssl_certificate']
    client.variable_value id, token: scope['conjur::token']
  end
end
