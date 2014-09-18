#!/opt/conjur/embedded/bin/ruby

host_id, token = ARGV

require 'conjur/api'
require 'conjur/config'
require 'conjur/authn'
require 'uri'
require 'conjur-asset-host-factory'

Conjur::Config.load [ '/etc/conjur.conf' ]
Conjur::Config.apply

host = Conjur::API.host_factory_create_host token, host_id

netrc = Conjur::Authn.netrc
netrc[Conjur::Authn.host] = [ "host/#{host['id']}", host['api_key'] ]
netrc.save
