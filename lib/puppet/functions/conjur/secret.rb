Puppet::Functions.create_function :'conjur::secret' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :secret do
    param 'Conjur::Endpoint', :client
    param 'String', :account
    param 'String', :variable_id
    param sensitive.name.split("::").last, :token
  end

  dispatch :with_defaults do
    param 'String', :variable_id
  end

  def secret client, account, id, token
    token = token.unwrap if token.respond_to? :unwrap
    sensitive.new client.variable_value account, id, token
  end

  def with_defaults id
    scope = closure_scope
    secret scope['conjur::client'], scope['conjur::authn_account'], id, scope['conjur::token']
  end
end
