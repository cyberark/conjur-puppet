require 'uri'

module Puppet::Parser::Functions
  newfunction(:conjur_token, type: :rvalue) do |args|
    url, login, key = args
    url += '/' # in case there is no trailing slash
    uri = URI url
    uri += "authn/users/" + URI.encode_www_form_component(login) + "/authenticate"
    http = Puppet::Network::HttpPool.http_ssl_instance uri.host, uri.port
    response = http.post uri.request_uri, key
    raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
    response.body
  end
end
