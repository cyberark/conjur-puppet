# frozen_string_literal: true

require 'conjur/puppet_module/ssl'

module Conjur
  module PuppetModule
    # This module is in charge of interacting with the Conjur endpoints
    module HTTP
      class << self
        def get(host_url, path, ssl_certificate, token)
          uri, use_ssl = parse_url(host_url, path)
          certs = Conjur::PuppetModule::SSL.load(ssl_certificate)

          headers = {}
          if token
            encoded_token = Base64.urlsafe_encode64(token)
            headers['Authorization'] = "Token token=\"#{encoded_token}\""
          end

          Net::HTTP.start uri.host, uri.port, use_ssl: use_ssl, cert_store: certs do |http|
            response = http.get(uri.request_uri, headers)

            raise Net::HTTPError.new response.message, response unless response.code.match?(%r{^2})

            response.body
          end
        end

        def post(host_url, path, ssl_certificate, data)
          uri, use_ssl = parse_url(host_url, path)

          raise(ArgumentError, "POST data to #{uri} must not be empty!") \
            if data.nil? || data.empty?

          certs = Conjur::PuppetModule::SSL.load(ssl_certificate)

          Net::HTTP.start uri.host, uri.port, use_ssl: use_ssl, cert_store: certs do |http|
            response = http.post(uri.request_uri, data)

            raise Net::HTTPError.new response.message, response unless response.code.match?(%r{^2})

            response.body
          end
        end

        private

        def parse_url(url, path)
          url += '/' unless url.end_with? '/'
          normalized_uri = URI(url) + path

          use_ssl = normalized_uri.scheme == 'https'

          unless use_ssl
            Puppet.warning("Conjur URL provided (#{url}) uses a non-HTTPS scheme" \
                           ' - YOU ARE VULNERABLE TO MITM ATTACKS!')
          end

          return normalized_uri, use_ssl
        end
      end
    end
  end
end
