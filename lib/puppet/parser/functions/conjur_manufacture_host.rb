require_relative '../../../conjur/puppet/client'

module Puppet::Parser::Functions
  newfunction(:conjur_manufacture_host, type: :rvalue, arity: 3) do |args|
    url, hostid, token = args
    client = Conjur::Puppet::Client.new url, lookupvar('conjur::ssl_certificate')
    client.create_host hostid, token
  end
end
