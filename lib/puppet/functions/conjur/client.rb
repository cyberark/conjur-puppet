# This function is really a Ruby class. Since we can't bind a class
# to a Ruby constant (which would dirty the interpreter state),
# we make it anonymous module and 'bless' a hash with it.
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
    {
      'uri' => uri,
      'cert' => cert
    }.extend self.class.conjur_client_module
  end

  def self.conjur_client_module
    # this is needed to thread the anonymous class through the blessing
    validator_class = self.validator_class

    @conjur_client_module ||= Module.new do
      def uri
        @uri ||= URI (self['uri'] + '/')
      end

      def cert
        @cert ||= self['cert'] && OpenSSL::X509::Certificate.new(self['cert'])
      end

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

      attr_reader :validator
      # this is needed to thread the anonymous class through the blessing
      @validator_class = validator_class
      def self.extended obj
        obj.instance_variable_set :@validator, @validator_class.new(obj.cert)
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
    end
  end

  def self.validator_class
    @validator_class ||= Class.new ::Puppet::SSL::Validator do
      def initialize cert
        @cert = cert
      end

      def setup_connection conn
        conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
        conn.verify_callback = self
        conn.cert_store = cert_store
        reset!
      end

      def cert_store
        @cert_store ||= OpenSSL::X509::Store.new.tap do |store|
          store.add_cert @cert if @cert
        end
      end

      def call ok, store
        @verify_errors << store.error_string unless ok
        ok
      end

      def reset!
        @verify_errors = []
      end

      def peer_certs
        return [] unless @cert
        [::Puppet::SSL::Certificate.from_instance(@cert)]
      end

      attr_reader :verify_errors
    end
  end
end
