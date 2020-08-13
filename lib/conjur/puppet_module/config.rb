# frozen_string_literal: true

module Conjur
  module PuppetModule
    # This module is in charge of retrieving Conjur configuration data
    # from the agent
    module Config
      CONFIG_FILE_PATH = '/etc/conjur.conf'
      REG_KEY_NAME = 'Software\CyberArk\Conjur'

      class << self
        def load
          Puppet.features.microsoft_windows? ? from_registry : from_file
        end

        def from_file
          if File.exist?(CONFIG_FILE_PATH)
            c = YAML.safe_load(File.read(CONFIG_FILE_PATH))
            c['ssl_certificate'] ||= File.read c['cert_file'] \
                if c['cert_file']
            c
          else
            {}
          end
        end

        def from_registry
          raise 'Conjur::PuppetModule::Config#from_registry is only supported on Windows' \
            unless Puppet.features.microsoft_windows?

          require 'win32/registry'

          c = {}
          begin
            Win32::Registry::HKEY_LOCAL_MACHINE.open(REG_KEY_NAME) do |reg|
              # Convert registry value names from camel case to underscores
              # e.g. ApplianceUrl => appliance_url
              c = reg.map { |name, _type, data| [name.gsub(%r{/(.)([A-Z])/}, '\1_\2').downcase, data] }.to_h
            end
          rescue
            Puppet.notice "Windows Registry on the agent did not contain path '#{REG_KEY_NAME}'. " \
                          'If this is the first time using server-provided credentials, this is ' \
                          'expected behavior.'
          end

          c['ssl_certificate'] ||= File.read c['cert_file'] if c['cert_file']

          c
        end
      end
    end
  end
end
