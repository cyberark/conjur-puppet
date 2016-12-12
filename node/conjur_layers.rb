Facter.add(:conjur_layers) do
  setcode do
    require 'yaml'
    require 'conjur-api'
    require 'netrc'

    def configure_conjur
      conjur_config = Puppet.settings[:conjur_config] || File.join(Puppet.settings[:confdir], 'conjur.yaml')
      if Puppet::FileSystem.exist?(conjur_config)
        config = YAML.load(File.read(conjur_config))
        Conjur.configuration.appliance_url = config['appliance_url'] or raise "Conjur url is required in conjur.yml"
        Conjur.configuration.account = config['account'] or raise "Conjur account is required in conjur.yml"
        if Conjur.configuration.cert_file.nil? && ( cert_file = config['cert_file'] )
          Conjur.configuration.cert_file = cert_file
          Conjur.configuration.apply_cert_config!
        end
      else
        raise "Conjur config file #{conjur_config} not found"
      end
    end

    configure_conjur

    def do_retry times, delay = 5, &block
      tries = 0
      begin
        yield
      rescue
        puts $!.message
        sleep delay
        if ( tries += 1 ) < times
          retry
        else
          raise
        end
      end
    end

    netrc_file = ENV['CONJUR_NETRC_PATH'] || File.expand_path("~/.netrc")
    netrc = Netrc.read(netrc_file)
    credentials = netrc[[ Conjur.configuration.appliance_url, "authn" ].join("/")] or raise "No Conjur credentials found in netrc file"
    login = credentials[0]
    kind, id = login.split('/', 2)
    conjur_api = Conjur::API.new_from_key(*credentials)

    role = conjur_api.send(kind, id).role
    role.memberships.select do |r|
      r.account == Conjur.configuration.account && r.kind == "layer"
    end.map do |r|
      r.identifier
    end
  end
end
