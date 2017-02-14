# This function is really a Ruby class. Since we can't bind a class
# to a Ruby constant (which would dirty the interpreter state),
# we make it anonymous and make it possible to refer to using
# a factory Puppet function.
Puppet::Functions.create_function :'conjur::client' do
  dispatch :new do
    param 'String', :uri
    param 'String', :cert
  end

  dispatch :new do
    param 'String', :uri
    # Apparently puppet dispatcher doesn't consider nil as 'param missing' and
    # passes an undef instead. Allow that here, even if it's mostly used in tests.
    optional_param 'Undef', :cert
  end

  def new uri, cert
    self.class.klass.validator_class ||= call_function 'conjur::validator'
    self.class.klass.new uri, cert
  end

  def self.klass
    @klass ||= Class.new(Struct.new :uri, :cert) do
      def initialize uri, cert
        if uri.respond_to? :request_uri
          @uri = uri
        else
          # not an URI instance, add slash in case it's ommited
          @uri = URI (uri + '/')
        end
        @cert = cert && OpenSSL::X509::Certificate.new(cert)
      end

      attr_reader :uri, :cert

      def authenticate login, key
        post "authn/users/" + URI.encode_www_form_component(login) + "/authenticate", key
      end

      def post path, content, encoded_token: nil
        if encoded_token
          headers = { 'Authorization' => "Token token=\"#{encoded_token}\"" }
        end
        response = http.post (uri + path).request_uri, content, headers
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end

      def http
        @http ||= ::Puppet::Network::HttpPool.http_ssl_instance uri.host, uri.port, validator
      end

      def validator
        @validator ||= self.class.validator_class.new cert
      end

      def variable_value id, token: nil
        get "variables/" + URI.encode_www_form_component(id) + "/value",
            encoded_token: Base64.urlsafe_encode64(token)
      end

      def get path, encoded_token: nil
        if encoded_token
          headers = { 'Authorization' => "Token token=\"#{encoded_token}\"" }
        end
        response = http.get (uri + path).request_uri, headers
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end

      def create_host id, token, annotations: {}
        data = {id: id}
        annotations.each do |k, v|
          data["annotations[#{k}]"] = v
        end
        response = post(
          "host_factories/hosts?" + URI.encode_www_form(data),
          nil,
          encoded_token: token
        )
        JSON.load response
      end

      class << self
        attr_accessor :validator_class
      end
    end
  end
end
