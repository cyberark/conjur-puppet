When("I retrieve the test page for {string}") do |agent_name|
  @result = retrieve_test_page(agent_name)
end

Then("the result contains the value for {string}") do |variable_id|
  expect(@result).to include(conjur_value(variable_id))
end

Then("the result does not contain the value for {string}") do |variable_id|
  expect(@result).not_to include(conjur_value(variable_id))
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
