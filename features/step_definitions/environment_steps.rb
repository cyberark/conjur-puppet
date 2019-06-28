Given("a puppet integration environment in AWS with agents:") do |agent_table|
  agents = agent_table.hashes.map { |hash| OpenStruct.new(hash) }
  terraform_aws_environment(agents)
end

Given("I load the integration Conjur policy") do
  load_integration_policy
end

Given("I install the current puppet module") do
  install_puppet_module
end
