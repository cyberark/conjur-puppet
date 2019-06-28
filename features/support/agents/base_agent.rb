module Agents
  class BaseAgent
    attr_reader :agent

    def initialize(agent, ndx)
      @agent = agent
      @ndx = ndx
    end

    def name
      agent.name
    end

    def platform
      agent.platform
    end

    def index
      @ndx
    end

    def host
      @host ||= Util::Terraform.output("puppet_agent_#{platform.downcase}_public_dns")[@ndx]
    end

    def ssh_private_key_pem
      @ssh_private_key_pem ||= Util::Terraform.output('ssh_key').strip
    end
  end
end
