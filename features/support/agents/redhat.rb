require_relative './base_agent'

module Agents
  class RedHat < BaseAgent
    def initialize(agent, ndx,
      appliance_url:,
      appliance_ca_cert:
    )
      super(agent, ndx)

      @appliance_url = appliance_url
      @appliance_ca_cert = appliance_ca_cert
    end

    def run
      ssh_exec(<<~EOS
        # Ensure puppet agent isn't currently running
        for i in $(seq 10); do
          sudo /opt/puppetlabs/bin/puppet agent --test

          if [ $? -eq 0 ] || [ $? -eq 2 ]; then
            break
          fi

          sleep 2
        done
      EOS
      )
    end

    def clear_identity
      ssh_exec(<<~EOS
        sudo rm -f /etc/conjur.conf
        sudo rm -f /etc/conjur.identity
      EOS
      )
    end

    def configure_identity(host_id:, api_key:)
      ssh_exec(<<~EOS
        echo '#{netrc_content(host_id, api_key)}' | sudo tee /etc/conjur.identity
        echo '#{@appliance_ca_cert}' | sudo tee /etc/conjur.pem
        echo '#{conjur_conf_content}' | sudo tee /etc/conjur.conf
      EOS
      )
    end

    private

    def ssh_exec(command)
      Net::SSH.start(
        host,
        'ec2-user',
        key_data: [ssh_private_key_pem],
        keys_only: true) do |ssh|
        ssh.exec!(command) do |_ch, stream, data|
          if stream == :stderr
            STDERR.print data
          else
            STDOUT.print data
          end
        end
      end
    end

    def netrc_content(host_id, host_apikey)
      <<~EOF
        machine #{@appliance_url}
        login #{host_id}
        password #{host_apikey}
      EOF
    end

    def conjur_conf_content
      <<~EOF
        appliance_url: #{@appliance_url}
        version: 5
        account: puppet
        cert_file: /etc/conjur.pem
      EOF
    end
  end
end
