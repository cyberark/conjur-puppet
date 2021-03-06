# frozen_string_literal: true

module Conjur
  module PuppetModule
    # This module is in charge of retrieving Conjur identity information
    # from the agent
    module Identity
      NETRC_FILE_PATH = '/etc/conjur.identity'

      class << self
        def load(config)
          appliance_url = config['appliance_url']

          unless appliance_url
            Puppet.warning('Conjur identity cannot be found as the appliance_url is empty')
            return []
          end

          uri = URI.parse(appliance_url)
          Puppet.features.microsoft_windows? ? from_wincred(uri) : from_file(uri, config)
        end

        def from_file(uri, config)
          netrc_path = config['netrc_path'] || NETRC_FILE_PATH

          return unless File.exist?(netrc_path)

          File.open netrc_path do |netrc|
            found = login = password = nil
            netrc.each_line do |line|
              key, value, = line.split
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

            Puppet.warning "Could not find Conjur authentication info for host '#{uri}'" unless found
            return []
          end
        end

        def from_wincred(uri)
          raise 'Conjur::PuppetModule::Identity#from_wincred is only supported on Windows' \
            unless Puppet.features.microsoft_windows?

          require 'wincred/wincred'

          Puppet.debug "Finding Conjur credentials in WinCred storage for uri: #{uri}"
          matching_creds = WinCred.enumerate_credentials.select do |cred|
            cred[:target].start_with?(uri.to_s) || \
              cred[:target] == "#{uri.host}:#{uri.port}" || \
              cred[:target] == uri.host
          end

          if matching_creds.empty?
            Puppet.warning 'Could not find any pre-populated Conjur credentials in WinCred ' \
                           "storage for #{uri}"
            return []
          end

          # We select the first one if there's multiple matches
          matching_cred = matching_creds.first

          Puppet.debug "Using Conjur credential '#{matching_cred[:target]}' for identity"
          [matching_cred[:username], matching_cred[:value].force_encoding('utf-16le').encode('utf-8')]
        end
      end
    end
  end
end
