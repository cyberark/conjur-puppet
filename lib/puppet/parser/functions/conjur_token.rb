require 'conjur/puppet/client'

module Puppet::Parser::Functions
  newfunction(:conjur_token, type: :rvalue, arity: 3) do |args|
    url, login, key = args
    client = Conjur::Puppet::Client[url]
    client.authenticate login, key
  end
end
