# frozen_string_literal: true

module Conjur
  module PuppetModule
    module Config
      CONFIG_FILE_PATH = '/etc/conjur.conf'
      REG_KEY_NAME = 'Software\CyberArk\Conjur'

      class << self
        def load
          from_file
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
      end
    end
  end
end
