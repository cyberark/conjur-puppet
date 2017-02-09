require 'puppet/ssl/validator'

module Conjur
  module Puppet
    class Validator < ::Puppet::SSL::Validator
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
