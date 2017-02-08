require 'puppetlabs_spec_helper/module_spec_helper'
require 'puppet/network/http/connection'
require 'puppet/network/http_pool'
require 'conjur/puppet/client'

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
        .with('conjur.test', 443, anything).and_return(conjur_connection)
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

module RSpec::Puppet
  module ClassExampleGroup
    def environment_module
      @envmod ||= Puppet::Parser::Functions.environment_module Puppet.lookup(:current_environment)
    end

    def allow_calling_puppet_function name
      Puppet::Parser::Functions.function name # to autoload
      allow_any_instance_of(environment_module).to receive(:"real_function_#{name}")
    end

    def lookupvar name
      # HACK There is no way to get to a local variable from the catalog:
      # by design, catalog contains only the external observable effects.
      # So instead synthesize a catalog by adding a dummy file
      # with the contents equal to variable to look up, then get lookup
      # its content in the catalog. Slow and convoluted, but seems to work.
      catalog = build_catalog 'test', {}, nil, """
        #{test_manifest(:class)}
        file { var:
          content => $#{name}
        }
      """, nil
      catalog.resource('File[var]')[:content]
    end
  end
end
