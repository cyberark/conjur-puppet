require 'uri'
require 'base64'

module Puppet::Parser::Functions
  newfunction(:conjur_secret, type: :rvalue) do |args|
    id = args.first
    uri = URI(lookupvar('conjur::appliance_url') + '/')
    uri += "variables/" + URI.encode_www_form_component(id) + "/value"
    http = Puppet::Network::HttpPool.http_ssl_instance uri.host, uri.port
    encoded_token = Base64.urlsafe_encode64 lookupvar 'conjur::token'
    response = http.get uri.request_uri, 'Authorization' => "Token token=\"#{encoded_token}\""
    response.body
  end
end
