# frozen_string_literal: true

RSpec.configure do |c|
  c.mock_with :rspec
end
require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

require 'spec_helper_local' if File.file?(File.join(File.dirname(__FILE__), 'spec_helper_local.rb'))

include RspecPuppetFacts

default_facts = {
  puppetversion: Puppet.version,
  facterversion: Facter.version,
  conjur_version: 5,
}

default_fact_files = [
  File.expand_path(File.join(File.dirname(__FILE__), 'default_facts.yml')),
  File.expand_path(File.join(File.dirname(__FILE__), 'default_module_facts.yml')),
]

default_fact_files.each do |f|
  next unless File.exist?(f) && File.readable?(f) && File.size?(f)

  begin
    default_facts.merge!(YAML.safe_load(File.read(f), [], [], true))
  rescue => e
    RSpec.configuration.reporter.message "WARNING: Unable to load #{f}: #{e}"
  end
end

# read default_facts and merge them over what is provided by facterdb
default_facts.each do |fact, value|
  add_custom_fact fact, value
end

RSpec.configure do |c|
  c.default_facts = default_facts
  c.mock_with :rspec
  c.expect_with :rspec do |expectations|
    expectations.max_formatted_output_length = nil
  end

  c.before :each do
    # set to strictest setting for testing
    # by default Puppet runs at warning level
    Puppet.settings[:strict] = :warning
    Puppet.settings[:strict_variables] = true
  end

  c.filter_run_excluding(bolt: true) unless ENV['GEM_BOLT']
  c.after(:suite) do
  end
end

shared_context 'mock conjur connection', conjur: :mock do
  let(:conjur_connection) do
    instance_double 'Net::HTTP', 'connection to Conjur'
  end

  before(:each) do
    allow(Net::HTTP).to receive(:start) \
      .with('conjur.test', 443, anything).and_return(conjur_connection)
  end

  def http_ok(body)
    Net::HTTPOK.new('1.1', '200', 'ok').tap do |resp|
      allow(resp).to receive(:body) { body }
    end
  end

  def http_unauthorized
    Net::HTTPUnauthorized.new '1.1', '403', 'unauthorized'
  end

  def expect_authorized_conjur_get(path)
    expect(conjur_connection).to receive(:get).with(
      path,
      'Authorization' => 'Token token="dGhlIHRva2Vu"', # "the token" b64d
    )
  end

  def allow_authorized_conjur_get(path)
    allow(conjur_connection).to receive(:get).with(
      path,
      'Authorization' => 'Token token="dGhlIHRva2Vu"', # "the token" b64d
    )
  end
end

module RSpec::Puppet
  module ClassExampleGroup
    def environment_module
      @envmod ||= Puppet::Parser::Functions.environment_module Puppet.lookup(:current_environment)
    end

    def allow_calling_puppet_function(name, method)
      loader = Puppet::Pops::Loaders.new adapter.current_environment
      fun = loader.private_environment_loader.load :function, name
      allow(fun).to receive(method)
    end

    def lookupvar(name)
      # HACK: There is no way to get to a local variable from the catalog:
      # by design, catalog contains only the external observable effects.
      # So instead synthesize a catalog by adding a dummy file
      # with the contents equal to variable to look up, then get lookup
      # its content in the catalog. Slow and convoluted, but seems to work.
      puppet_code = <<-END
        #{test_manifest(:class)}
        file { var:
          content => $#{name}
        }
      END
      catalog = build_catalog('test', facts_hash('conjur'), nil, nil,
                              puppet_code,
                              nil,
                              {})
      catalog.resource('File[var]')[:content]
    end
  end
end

# Ensures that a module is defined
# @param module_name Name of the module
def ensure_module_defined(module_name)
  module_name.split('::').reduce(Object) do |last_module, next_module|
    last_module.const_set(next_module, Module.new) unless last_module.const_defined?(next_module, false)
    last_module.const_get(next_module, false)
  end
end

# 'spec_overrides' from sync.yml will appear below this line
