Puppet::Functions.create_function :'conjur::manufacture_host' do
  dispatch :create do
    param 'Conjur::Endpoint', :client
    param 'String', :id
    param 'Sensitive', :token
  end

  def create client, hostid, token
    client.create_host(hostid, token.unwrap, annotations: { puppet: true }).tap do |result|
      result['api_key'] =
          Puppet::Pops::Types::PSensitiveType::Sensitive.new result['api_key'] \
          if result['api_key']
    end
  end
end
