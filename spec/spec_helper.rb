require 'puppetlabs_spec_helper/module_spec_helper'
require 'puppet/network/http/connection'
require 'puppet/network/http_pool'

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end
end

shared_context "mock conjur connection", conjur: :mock do
  let(:conjur_connection) do
    instance_double 'Puppet::Network::HTTP::Connection', 'connection to Conjur'
  end

  before do
    allow(Puppet::Network::HttpPool).to receive(:http_ssl_instance) \
        .with('conjur.test', 443).and_return(conjur_connection)
  end

  def http_ok body
    Net::HTTPOK.new('1.1', '200', 'ok').tap do |resp|
      allow(resp).to receive(:body) { body }
    end
  end

  def http_unauthorized
    Net::HTTPUnauthorized.new '1.1', '403', 'unauthorized'
  end

  def expect_authorized_conjur_get path
    expect(conjur_connection).to receive(:get).with path,
      'Authorization' => 'Token token="dGhlIHRva2Vu"' # "the token" b64d
  end
end
