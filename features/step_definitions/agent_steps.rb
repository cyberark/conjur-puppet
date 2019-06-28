Then("the test page for {string} contains the value for {string}") do |agent_name, variable_id|
  with_retry do
    result = retrieve_test_page(agent_name)
    expect(result).to include(conjur_value(variable_id))
  end
end

Then("the test page for {string} does not contain the value for {string}") do |agent_name, variable_id|
  with_retry do
    result = retrieve_test_page(agent_name)
    expect(result).not_to include(conjur_value(variable_id))
  end
end

Given("I clear the Conjur identity for {string}") do |agent_name|
  clear_conjur_identity(agent_name)
end

Given("I trigger the puppet agent on {string}") do |agent_name|
  run_puppet_agent(agent_name)
end

Given("I add configure {string} with the Conjur identity for {string}") do |agent_name, host_id|
  configure_conjur_identity(agent_name, host_id)
end
