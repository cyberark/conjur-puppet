require 'spec_helper'
require 'webrick'
require 'webrick/https'

describe 'conjur::client' do
  include RSpec::Puppet::FunctionExampleGroup
  let(:pem) { cert && cert.to_pem }
  let(:version) { 5 }
  subject(:client) { find_function.execute uri, version, pem }

  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) { { os: { family: os_family } } }

      context "with certificate for localhost" do
        it "when the cert checks out it connects correctly" do
          expect { client.get 'test' }.to_not raise_error
        end

        context "with a cert bundle" do
          let(:pem) do
            [
              (make_cert 'unrelated.test').to_pem,
              cert.to_pem,
            ].join
          end

          it "trusts all certificates in the bundle" do
            expect { client.get 'test' }.to_not raise_error
          end
        end

        context "when the certificate doesn't verify" do
          let(:cert_hostname) { 'not.localhost' }
          it "it errors out" do
            expect { client.get 'test' }.to raise_error /verify failed/
          end
        end

        let(:cert_hostname) { 'localhost' }
        let(:uri) { "https://localhost:#{port}" }
        let(:port) { 31390 }

        let(:server) do
          WEBrick::HTTPServer.new(
            Port: port, SSLEnable: true,
            SSLCertificate: cert, SSLPrivateKey: rsa,
            Logger: WEBrick::Log.new(STDERR, ($DEBUG ? 4 : 1)),
            AccessLog: $DEBUG ? nil : []
          ).tap do |server|
            server.mount_proc '/test' do |req, res|
              res.body = 'ok'
            end
          end
        end
        before { @server_thread = Thread.new { server.start }; sleep 0.1 }
        after { server.shutdown; @server_thread.join }

        def make_cert name
          cert = OpenSSL::X509::Certificate.new
          cert.version = 2
          cert.serial = 1
          name = OpenSSL::X509::Name.new([['CN', name]])
          cert.subject = name
          cert.issuer = name
          cert.not_before = Time.now
          cert.not_after = Time.now + (365*24*60*60)
          cert.public_key = rsa.public_key
          cert.sign(rsa, OpenSSL::Digest::SHA256.new)
          cert
        end

        let(:cert) { make_cert cert_hostname }

        let(:rsa) do
          OpenSSL::PKey.read """
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAqUeQuETZ8lTjER+YWeFZRY4AjBWYaKzmL/M48twgvw1ai89X
ZqZnO9IeWYCYIcDU4gDDJv3YbYSgGGC5WlJQrXgsTPNHlueVbg0GtN1+ZfqQXJSC
cwwgy+E2STKdLHadmeaPHxd1crtgJRh1W+fHUOSV/xd4O01NRdUUX3g+KPph2uxU
L8Wdc9GBfBmrHipr9jBhGXyq8JxaW12nLX11MFAZeCEq2PxJ6PAJJANgTtRV4Psh
FbiJb/DB7PugYt3gFvi7gthXD9AimvdDYZjFeQPgTVfu1EuvVjcenSO4upPTApmo
UxEOKoUqkXvDzUMa6hwrk9gwOBRBO34UDCNggwIDAQABAoIBAQCf1MGRKvk59Op8
hX99BegbY0ui+NTxqKajCZxwumV03q/qqDfW5TE961PaoC+EVyTpy1x32WBbb8kV
m2YHIQep8nipo16p3jlaMpRte2DX+vAJafONmxrwRdHS5SZAEDMYV/g0nBq53K+X
9vMAduTbvSjfNZLBM2jNkbXtuoO+fbjXsPIdZYGghEhOuRR5qOdfkoSTxK8xCymB
1/jc5U4ZDP4Ah5y9p9cfd/i6o4Oai7gmQ0rHOg6UCbhTOmqyXPhfOGGZ0fCnoaYm
eRRU9exezaiDjaUa29INr/pUnwH1PCW3zChemKlZ6qcT2VO2VeDesm3x9dPL+pjF
99m5mSThAoGBANyYgxSk6Y+gpGvMqwSMlwgmGnZGq2EBGK9uzLHg5cG/VL4uS9Pm
bOPiVx9/NgCzKN5VRJQda9GAa9ReSBWzQa2m7bHUYr0ywNfYSw3seFcV9I/I4qpk
0bZ0VtnJ/cbK+A7kkQZuS43Q+1OrIXi4yh4JdHN27k7KB3jJxWmPKp6RAoGBAMRy
p6DYgrAyrW0/QuIl8GeBW1/hugFeJKo+3iuUHTrvKcmAvhzgwonJH6hLrw9U2GfN
3AUwHTNUHJv8fz/AYRQwxGB02iF4qt5q2ndz1bjSqYtmZKAKk643xlAEb7HiYKfB
95H92sl4gTFjf52tvu3Kke43ZnmE3D08jYV3rT/TAoGBAKcvOyD5Pz4oTJSan/4p
owl8/08mjhpNn2zN93rUbKzjGhGsurFVEK/BSbBIVCBBqDagvwHWLnGv94kTD2TK
33sBaWH+CftELN0pQvDBiA7QR/J1GDx1fm7eSzhyGtB/4XJADh2ml8JaYS/vIcYB
nsUW+1fLCh9ShEkp+mDfLTjRAoGAIbKxQowhTuxCh5z0ciqj5H1yGS51Y8qsa2/B
WKRdp0BjYKdu9TEw7cXMYmgpLW4WeSf89/7a43UoOzHC+kKb5ITBCvLAgEFcvi6C
Lz91h/DLGJiF5lYqIxZ6NDuulUsJ3X0OZMKxByJetwQkXf3x5IR9J+nk8C90QCTk
+eIfm/UCgYAfMDvt9lFtzTOSYz/sOOvhrLfENwQkye503IFr5VMeSnVGOr/JPv0K
Nbnwa5QA4F0bWcEWTI62J6c6Rg2nFhaHj9/IT8x9+f1GytXp5cePD/LPkMJbkG79
xCbuhI/IUunMm+F/8gOcAGd9L3j0g5ZOsGSF34NXi21BrlFGQdWFzg==
-----END RSA PRIVATE KEY-----
      """
        end
      end

      context "with mock conjur service", conjur: :mock do
        let(:uri) { "https://conjur.test" }
        let(:cert) { nil }
        describe '#create_host' do
          it "creates a host and returns the description hash" do
            allow(conjur_connection).to receive(:post) \
                .with(anything, nil,
                      "Authorization" => "Token token=\"hostfactorytokenn\"") \
            do |request_path|
              uri = URI request_path
              expect(uri.path).to eq '/host_factories/hosts'
              expect(URI.decode_www_form uri.query).to include(
                ['id', 'test+plus!'], ['annotations[puppet]', 'true'])
              http_ok '{ "api_key": "theapikey" }'
            end

            expect(subject.create_host 'test+plus!', 'hostfactorytokenn',
                  annotations: { puppet: true })\
                .to eq "api_key" => 'theapikey'
          end
        end

        describe '#authenticate' do
          shared_examples "authentication" do
            it "exchanges API key for token" do
              expect(subject.authenticate 'alice', 'the api key', 'test')\
                  .to eq 'the token'
            end
          end

          context "with Conjur v5 API" do
            before do
              allow(conjur_connection).to receive(:post) \
                  .with('/authn/test/alice/authenticate', 'the api key', nil) \
                  .and_return http_ok 'the token'
            end
            let(:version) { 5 }
            include_examples "authentication"
          end

      it "correctly encodes username" do
        allow(conjur_connection).to receive(:post) \
            .with('/authn/test/host%2Fpuppettest/authenticate', 'the api key', nil) \
            .and_return http_ok 'the host token'

        expect(subject.authenticate 'host/puppettest', 'the api key', 'test') \
            .to eq 'the host token'
        end

        it "raises error when server errors" do
          allow(conjur_connection).to receive(:post) \
              .with('/authn/test/alice/authenticate', 'the api key', nil) \
              .and_return http_unauthorized

          expect { subject.authenticate 'alice', 'the api key', 'test' } \
              .to raise_error Net::HTTPError
          end
        end
      end
    end
  end
end
