# frozen_string_literal: true

module Conjur
  module PuppetModule
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
          values = []
          Win32::Registry::HKEY_LOCAL_MACHINE.open(REG_KEY_NAME) do |reg|
            reg.each_value do |name, _type, data|
              # Convert registry value names from camel case to underscores
              # e.g. ApplianceUrl => appliance_url
              values << [name.gsub(/(.)([A-Z])/, '\1_\2').downcase, data]
            end
          end

          values.to_h
        end
      end
    end
  end
end
