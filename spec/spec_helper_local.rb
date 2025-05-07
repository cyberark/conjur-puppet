
# frozen_string_literal: true

# Ensure that SimpleCov loads before anything else
require 'simplecov'
require 'simplecov-cobertura'

SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
SimpleCov.start

# Loads a static fixture file from a common dir
def fixture_file(path)
  File.read("spec/fixtures/files/#{path}")
end
