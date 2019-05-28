module Conjur
  module Config
    CONFIG_FILE_PATH = '/etc/conjur.conf'.freeze

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
