module Conjur
  module PuppetModule
    module Identity
      NETRC_FILE_PATH = '/etc/conjur.identity'.freeze

      class << self
        def load(config)
          if (url = config['appliance_url'])
            uri = URI.parse(url)
            Puppet.features.microsoft_windows? ? from_wincred(uri) : from_file(uri, config)
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

        def from_wincred(uri)
          raise 'Conjur::PuppetModule::Identity#from_wincred is only supported on Windows' \
            unless Puppet.features.microsoft_windows?

          require 'wincred/wincred'

          WinCred.enumerate_credentials
                  .select { |cred| cred[:target].start_with?(uri.to_s) || cred[:target] == uri.host }
                  .map { |cred| [cred[:username], cred[:value]] }
                  .first
        end
      end
    end
  end
end
