require 'spec_helper'
require 'webrick'
require 'webrick/https'

describe 'conjur::client' do
  include RSpec::Puppet::FunctionExampleGroup
  let(:pem) { cert && cert.to_pem }
  let(:version) { 4 }
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
        let(:uri) { "https://localhost:#{port}/api/" }
        let(:port) { 31390 }

        let(:server) do
          WEBrick::HTTPServer.new(
            Port: port, SSLEnable: true,
            SSLCertificate: cert, SSLPrivateKey: rsa,
            Logger: WEBrick::Log.new(STDERR, ($DEBUG ? 4 : 1)),
            AccessLog: $DEBUG ? nil : []
          ).tap do |server|
            server.mount_proc '/api/test' do |req, res|
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
MIICXAIBAAKBgQCrg4s4NiHMC0PbVzyaGI0ZXBm8deNheOsLPdzpwX8U+MIyWE72
+QZJ9lRT/T7eoa6wN+3ChaucjA5am6l32bnbUttMKFZY8wPg1VKB3DDtfeZI8AiI
FHylKbf3Mcx6MQAFObUCe5M08YRBzprKqqYhNhdZh0XKDkv4dkeTVgn3kQIDAQAB
AoGBAI6zOJ8BMudwq/mPwIU5ThQ+c89AinmrwGuvAeGfM1vAiNqYbMLBeIELKShk
OO3EufI15mUFED6ErOCoSLzF8wJxZeCwtu4bc8QfYlkCBU7epPS/K+dvMTxJGWOx
lIpmV1NRn6qFNSxNvFd2d79c3qAEeco90jEn9CKp4c3WKCURAkEA4fO/Z4IrpUcX
KsJ7zDPsviQlbK1qBeZ4QyabvFzx/uHpa3z1fY+0U9Xd86XAZM2Y0eJ6/7c4SIYO
yLXuBUuOjQJBAMJSg4jJjZ5BhkseCKll6CJBAfxvVel5jYtGzYk83VC00TQW5QBh
oOTaawjkLUB199bJeDSdSI33x4SGEvhd3hUCQHMCLHS1Lx4LV2FuaLEB5QjLQTlV
81dZffFAH5j6/josJzGNAy+MC894VmcEAS/N7nE2hEDQs5dGlRPYdnS/hqkCQBpC
/oXI/3uozVZvi6ohHJssf/E2tryj8c4l1nc6o4pZtYA9q9s+Vnk3T4nXFIqGpuT/
O2CY9QpCt1Mgr4WjYfUCQHiUgB/9dsgiTaFiQjLe6Vr/YaGUuSG1ussqJpmYcoyM
xLU2GspOjINCXuUBvSamEanZpWTYjHshPqVZKlsoV1A=
-----END RSA PRIVATE KEY-----
      """
        end
      end

      context "with mock conjur service", conjur: :mock do
        let(:uri) { "https://conjur.test/api" }
        let(:cert) { nil }
        describe '#create_host' do
          it "creates a host and returns the description hash" do
            allow(conjur_connection).to receive(:post) \
                .with(anything, nil,
                      "Authorization" => "Token token=\"hostfactorytokenn\"") \
            do |request_path|
              uri = URI request_path
              expect(uri.path).to eq '/api/host_factories/hosts'
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

          context "with Conjur v4 API" do
            before do
              allow(conjur_connection).to receive(:post) \
                  .with('/api/authn/users/alice/authenticate', 'the api key', nil) \
                  .and_return http_ok 'the token'
            end

            include_examples "authentication"
          end

          context "with Conjur v5 API" do
            before do
              allow(conjur_connection).to receive(:post) \
                  .with('/api/authn/test/alice/authenticate', 'the api key', nil) \
                  .and_return http_ok 'the token'
            end
            let(:version) { 5 }
            include_examples "authentication"
          end

      it "correctly encodes username" do
        allow(conjur_connection).to receive(:post) \
            .with('/api/authn/users/host%2Fpuppettest/authenticate', 'the api key', nil) \
            .and_return http_ok 'the host token'

        expect(subject.authenticate 'host/puppettest', 'the api key') \
            .to eq 'the host token'
        end

        it "raises error when server errors" do
          allow(conjur_connection).to receive(:post) \
              .with('/api/authn/users/alice/authenticate', 'the api key', nil) \
              .and_return http_unauthorized

          expect { subject.authenticate 'alice', 'the api key' } \
              .to raise_error Net::HTTPError
          end
        end
      end
    end
  end
end
