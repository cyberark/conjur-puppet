# frozen_string_literal: true

require_relative 'ssl'

module Conjur
  module PuppetModule
    # This module is in charge of interacting with the Conjur endpoints
    module HTTP
      class << self
        def get(host_url, path, ssl_certificate, token)
          headers = {}
          if token
            encoded_token = Base64.urlsafe_encode64(token)
            headers['Authorization'] = "Token token=\"#{encoded_token}\""
          end

          start_http_request(host_url, path, ssl_certificate) do |http, uri|
            http.get(uri.request_uri, headers)
          end
        end

        def post(host_url, path, ssl_certificate, data, token = nil)
          headers = {}
          if token
            headers['Authorization'] = "Token token=\"#{token}\""
          end

          start_http_request(host_url, path, ssl_certificate) do |http, uri|
            http.post(uri.request_uri, data, headers)
          end
        end

        private

        def start_http_request(host_url, path, ssl_certificate)
          uri, use_ssl = parse_url(host_url, path)
          certs = Conjur::PuppetModule::SSL.load(ssl_certificate)

          Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl, cert_store: certs) do |http|
            response = yield http, uri

            raise Net::HTTPError.new response.message, response unless response.code.match?(%r{^2})

            response.body
          end
        end

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
