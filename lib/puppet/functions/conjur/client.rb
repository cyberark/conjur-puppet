require 'net/http'

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
    uri = URI (uri + '/')
    {
      'uri' => uri.to_s,
      'cert' => cert
    }.extend self.class.conjur_client_module
  end

  def self.conjur_client_module
    @conjur_client_module ||= Module.new do
      def uri
        @uri ||= URI self['uri']
      end

      def cert
        cert_header = '-----BEGIN CERTIFICATE-----'.freeze
        cert_footer = '-----END CERTIFICATE-----'.freeze
        cert_re = /#{cert_header}\r?\n.*?\r?\n#{cert_footer}/m.freeze

        @cert ||= self['cert'] && \
            self['cert'].scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
      end

      def cert_store
        @cert_store ||= cert && OpenSSL::X509::Store.new.tap do |store|
          cert.each &store.method(:add_cert)
        end
      end

      def authenticate login, key
        post "authn/users/" + URI.encode_www_form_component(login) + "/authenticate", key
      end

      def post path, content, encoded_token = nil
        if encoded_token
          headers = { 'Authorization' => "Token token=\"#{encoded_token}\"" }
        end
        response = http.post (uri + path).request_uri, content, headers
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end

      def http
        @http ||= ::Net::HTTP.start uri.host, uri.port,
            use_ssl: (uri.scheme == 'https'),
            cert_store: cert_store
      end

      def variable_value id, token = nil
        get "variables/" + URI.encode_www_form_component(id) + "/value",
            Base64.urlsafe_encode64(token)
      end

      def get path, encoded_token = nil
        if encoded_token
          headers = { 'Authorization' => "Token token=\"#{encoded_token}\"" }
        end
        response = http.get (uri + path).request_uri, headers
        raise Net::HTTPError.new response.message, response unless response.code =~ /^2/
        response.body
      end

      def create_host id, token, opts = {}
        annotations = opts.delete(:annotations) || {}
        data = {id: id}
        annotations.each do |k, v|
          data["annotations[#{k}]"] = v
        end
        response = post(
          "host_factories/hosts?" + URI.encode_www_form(data),
          nil,
          token
        )
        JSON.load response
      end
    end
  end
end
