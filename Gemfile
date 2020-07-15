source ENV['GEM_SOURCE'] || 'https://rubygems.org'

# 5.5.1 is the oldest officially supported version as of 2019-04
puppetversion = ENV['PUPPET_VERSION'].to_s.empty? ? '~> 6.17.0' : ENV['PUPPET_VERSION']

gem 'metadata-json-lint'
gem 'puppet', puppetversion
gem 'puppetlabs_spec_helper', '>= 1.0.0'
gem 'puppet-lint', '~> 2.1.0'
gem 'puppet-blacksmith', '~> 4.1.0'
gem 'facter', '>= 1.7.0'
gem 'rspec-puppet', git: 'https://github.com/rodjek/rspec-puppet.git'
gem 'rspec_junit_formatter'

gem 'rubocop'
