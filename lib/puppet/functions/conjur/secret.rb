Puppet::Functions.create_function :'conjur::secret' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :secret do
    param 'Conjur::Endpoint', :client
    param 'String', :variable_id
    param sensitive.name.split("::").last, :token
  end

  dispatch :with_defaults do
    param 'String', :variable_id
  end

  def secret client, id, token
    token = token.unwrap if token.respond_to? :unwrap
    sensitive.new client.variable_value id, token: token
  end

  def with_defaults id
    scope = closure_scope
    secret scope['conjur::client'], id, scope['conjur::token']
  end
end
