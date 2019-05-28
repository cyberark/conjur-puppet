module Conjur
  module Identity
    NETRC_FILE_PATH = '/etc/conjur.identity'.freeze

    class << self
      def load(config)
        if (url = config['appliance_url'])
          uri = URI.parse(url)
          from_file(uri, config)
        end
      end

      def from_file(uri, config)
        netrc_path = config['netrc_path'] || NETRC_FILE_PATH

        return unless File.exist?(netrc_path)

        File.open netrc_path do |netrc|
          found = login = password = nil
          netrc.each_line do |line|
            key, value, _ = line.split
            case key
            when 'machine'
              found = value.start_with?(uri.to_s) || value == uri.host
            when 'login'
              login = value if found
            when 'password'
              password = value if found
            end
            return [login, password] if login && password
          end
        end
      end
    end
  end
end
