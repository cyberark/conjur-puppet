require 'net/ssh'
require 'net/scp'
require 'json'
require 'winrm'

module PuppetHelper
  def install_puppet_module
    return if $puppet_module_installed

    install_module
    upload_manifest
    $puppet_module_installed = true
  end

  def retrieve_test_page(agent_name)
    host = agent(agent_name).host or return
    uri = URI("http://#{host}")

    # Give the agent 1 minute to return the test page
    10.times.reverse_each do |i|
      begin
        return Net::HTTP.get(uri)
      rescue Timeout::Error,
            Errno::EINVAL,
            Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse,
            Net::HTTPHeaderSyntaxError,
            Net::ProtocolError
        raise if i.zero?

        sleep 6
      end
    end
  end

  def clear_conjur_identity(agent_name)
    agent(agent_name).clear_identity
  end

  def configure_conjur_identity(agent_name, host_id)
    agent(agent_name).configure_identity(
      host_id: 'host/preconfigured_host',
      api_key: preconfigured_apikey
    )
  end

  def run_puppet_agent(agent_name)
    agent(agent_name).run
  end

  private

  def install_module
    ssh_upload("./pkg/#{module_filename}", "/home/ec2-user/#{module_filename}")
    ssh_exec(<<~EOS
      sudo /opt/puppetlabs/bin/puppet module uninstall cyberark-conjur
      sudo /opt/puppetlabs/bin/puppet module install /home/ec2-user/#{module_filename}
      sudo /opt/puppetlabs/bin/puppet module install dalen/trycatch
    EOS
    )
  end

  def upload_manifest
    ssh_upload(StringIO.new(puppet_manifest), '/home/ec2-user/site.pp')
    ssh_exec(<<~EOS
      sudo cp -Rv /home/ec2-user/site.pp /etc/puppetlabs/code/environments/production/manifests/site.pp
      sudo chmod 444 /etc/puppetlabs/code/environments/production/manifests/site.pp
    EOS
    )
  end

  def puppet_master_host
    @puppet_master_host ||= Util::Terraform.output('puppet_master_public').strip
  end

  def module_filename
    "cyberark-conjur-#{module_version}.tar.gz"
  end

  def module_version
    @module_version ||= JSON.parse(File.read('metadata.json'))['version']
  end

  def agent(name)
    agent = $agents.find { |record| record.name == name }

    ndx = $agents.select { |record| record.platform == agent.platform }
                 .index { |record| record.name == name }

    case agent.platform.downcase
    when 'redhat'
      Agents::RedHat.new(agent, ndx,
        appliance_url: appliance_url,
        appliance_ca_cert: conjur_ca_certificate
        )
    when 'windows'
      Agents::Windows.new(agent, ndx,
        appliance_url: appliance_url,
        appliance_host: appliance_hostname,
        appliance_ca_cert: conjur_ca_certificate
        )
    else
      raise "Invalid platform (#{agent.platform}) given for agent '#{agent.name}'"
    end
  end

  def puppet_manifest
    ERB.new(File.read('ci/template/puppet/site.pp.erb')).result(binding)
  end

  def ssh_exec(command)
    Net::SSH.start(
      puppet_master_host,
      'ec2-user',
      key_data: [ssh_private_key_pem],
      keys_only: true) do |ssh|
        ssh.exec!(command) do |ch, stream, data|
          if stream == :stderr
            STDERR.print data
          else
            STDOUT.print data
          end
        end
    end
  end

  def ssh_upload(source, dest)
    Net::SSH.start(
      puppet_master_host,
      'ec2-user',
      key_data: [ssh_private_key_pem],
      keys_only: true) do |ssh|
      ssh.scp.upload!(source, dest)
    end
  end

  def ssh_private_key_pem
    @ssh_private_key_pem ||= Util::Terraform.output('ssh_key').strip
  end
end

World(PuppetHelper)
