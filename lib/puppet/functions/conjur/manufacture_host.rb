Puppet::Functions.create_function :'conjur::manufacture_host' do
  sensitive = Puppet::Pops::Types::PSensitiveType::Sensitive rescue String
  send(:define_method, :sensitive) { sensitive }

  dispatch :create do
    param 'Conjur::Endpoint', :client
    param 'String', :id
    param sensitive.name.split("::").last, :token
  end

  def create client, hostid, token
    token = token.unwrap if token.respond_to? :unwrap
    client.create_host(hostid, token, annotations: { puppet: true }).tap do |result|
      result['api_key'] = sensitive.new result['api_key'] if result['api_key']
    end
  end
end
