require 'spec_helper'
require 'conjur/puppet/client'
require 'webrick'
require 'webrick/https'

describe Conjur::Puppet::Client do
  subject(:client) { Conjur::Puppet::Client.new uri, cert }

  it "when the cert checks out it connects correctly" do
    expect { client.get 'test' }.to_not raise_error
  end

  context "when the certificate doesn't verify" do
    let(:cert_hostname) { 'not.localhost' }
    it "it errors out" do
      expect { client.get 'test' }.to raise_error /expected not.localhost/
    end
  end

  let(:cert_hostname) { 'localhost' }
  let(:uri) { URI "https://localhost:#{port}/api/" }
  let(:port) { 31390 }

  let(:server) do
    WEBrick::HTTPServer.new(
      Port: port, SSLEnable: true, SSLCertificate: cert, SSLPrivateKey: rsa
    ).tap do |server|
      server.mount_proc '/api/test' do |req, res|
        res.body = 'ok'
      end
    end
  end
  before { @server_thread = Thread.new { server.start }; sleep 0.1 }
  after { server.shutdown; @server_thread.join }

  let(:cert) do
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    name = OpenSSL::X509::Name.new([['CN', cert_hostname]])
    cert.subject = name
    cert.issuer = name
    cert.not_before = Time.now
    cert.not_after = Time.now + (365*24*60*60)
    cert.public_key = rsa.public_key
    cert.sign(rsa, OpenSSL::Digest::SHA256.new)
    cert
  end

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
