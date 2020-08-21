# frozen_string_literal: true

module Conjur
  module PuppetModule
    # This module is a bundle of helper methods for handling the SSL and certificate
    # logic
    module SSL
      class << self
        def load(ssl_certificate)
          if ssl_certificate.nil? || ssl_certificate.empty?
            Puppet.warning('No Conjur SSL certificate - YOU ARE VULNERABLE TO MITM ATTACKS!')
            return []
          end

          cert_store = OpenSSL::X509::Store.new
          parsed_certs = parse_certs(ssl_certificate)

          Puppet.info("Parsed #{parsed_certs.length} certificate(s) from SSL cert chain")

          parsed_certs.each do |x509_cert|
            cert_store.add_cert x509_cert
          end

          cert_store
        end

        def parse_certs(certs)
          cert_header = '-----BEGIN CERTIFICATE-----'
          cert_footer = '-----END CERTIFICATE-----'
          cert_re = %r{#{cert_header}\r?\n.*?\r?\n#{cert_footer}}m

          certs.scan(cert_re).map(&OpenSSL::X509::Certificate.method(:new))
        end
      end
    end
  end
end
