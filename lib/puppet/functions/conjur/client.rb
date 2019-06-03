# frozen_string_literal: true

require 'net/http'

# This function is really a Ruby class. Since we can't bind a class
# to a Ruby constant (which would dirty the interpreter state),
# we make it anonymous module and 'bless' a hash with it.
Puppet::Functions.create_function :'conjur::client' do
  dispatch :new do
    param 'String', :uri
    param 'Integer', :version
    param 'String', :cert
  end

  dispatch :new do
    param 'String', :uri
    param 'Integer', :version
    # Apparently puppet dispatcher doesn't consider nil as 'param missing' and
    # passes an undef instead. Allow that here, even if it's mostly used in tests.
    optional_param 'Undef', :cert
  end

  def new uri, version, cert
    # A common mistake is to omit the trailing slash in the Conjur address.
    # Conjur API is always at a directory level, so make sure it's right.
    uri += '/' unless uri.end_with? '/'
    {
      'uri' => uri,
      'version' => version,
      'cert' => cert
    }.extend self.class.conjur_client_module
  end

  def self.conjur_client_module
    @conjur_client_module ||= Module.new do
      def uri
        @uri ||= URI self['uri']
      end

      def cert
        cert_header = '-----BEGIN CERTIFICATE-----'
        cert_footer = '-----END CERTIFICATE-----'
        cert_re = /#{cert_header}\r?\n.*?\r?\n#{cert_footer}/m

        @cert ||= self['cert'] && \
            self['cert'].scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
      end

      def cert_store
        @cert_store ||= cert && OpenSSL::X509::Store.new.tap do |store|
          cert.each &store.method(:add_cert)
        end
      end

      def version
        @version ||= self['version']
      end

      def authenticate login, key, account = nil
        case version
        when 4
          account = 'users'
        when 5
          raise ArgumentError, "account is required for v5" unless account
        end
        post ['authn', account, login, 'authenticate'].
            map(&URI.method(:encode_www_form_component)).join('/'), key
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

      def variable_value account, id, token = nil
        path = case version
          when 4
            ['variables', URI.encode_www_form_component(id), 'value']
          when 5
            raise ArgumentError, "account is required for v5" unless account
            ['secrets', account, 'variable', id]
          end.join('/')
        get path, Base64.urlsafe_encode64(token)
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
