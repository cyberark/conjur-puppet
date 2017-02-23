Puppet::Functions.create_function :'conjur::secret' do
  dispatch :secret do
    param 'Conjur::Endpoint', :client
    param 'String', :variable_id
    param 'String', :token
  end

  dispatch :with_defaults do
    param 'String', :variable_id
  end

  def secret client, id, token
    client.variable_value id, token: token
  end

  def with_defaults id
    scope = closure_scope
    secret scope['conjur::client'], id, scope['conjur::token']
  end
end
