# frozen_string_literal: true

# Ensure that SimpleCov loads before anything else
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
SimpleCov.start

# Ensure that RSpec is set as mocking framework before anything else
# as the `require` statements throw warnings otherwise
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

# Loads a static fixture file from a common dir
def fixture_file(path)
  File.read("spec/fixtures/files/#{path}")
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
