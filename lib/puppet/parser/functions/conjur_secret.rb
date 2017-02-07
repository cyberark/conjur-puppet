require 'conjur/puppet/client'

module Puppet::Parser::Functions
  newfunction(:conjur_secret, type: :rvalue, arity: 1) do |args|
    client = Conjur::Puppet::Client[lookupvar('conjur::appliance_url')]
    client.variable_value args.first, token: lookupvar('conjur::token')
  end
end
