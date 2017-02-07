require 'uri'

module Conjur
  module Puppet
    class Client < Struct.new :uri
      def self.[] appliance_url
        uri = URI (appliance_url + '/') # in case there's no trailing slash
        @clients ||= Hash.new do |h, k|
          h[uri] = Client.new uri
        end
        @clients[uri]
      end

      def self.clear
        @clients = nil
      end

      def authenticate login, key
        post "authn/users/" + URI.encode_www_form_component(login) + "/authenticate", key
      end

      def post path, content
        response = http.post (uri + path).request_uri, content
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end

      def http
        @http ||= ::Puppet::Network::HttpPool.http_ssl_instance uri.host, uri.port
      end

      def variable_value id, token: nil
        get "variables/" + URI.encode_www_form_component(id) + "/value", token: token
      end

      def get path, token: nil
        encoded_token = Base64.urlsafe_encode64 token
        response = http.get (uri + path).request_uri, 'Authorization' => "Token token=\"#{encoded_token}\""
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end
    end
  end
end
