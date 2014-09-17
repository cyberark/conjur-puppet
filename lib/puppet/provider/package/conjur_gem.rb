require 'puppet/provider/package/gem'

Puppet::Type.type(:package).provide(:conjur_gem, :parent => :gem) do
  commands :gemcmd => '/opt/conjur/embedded/bin/gem'
end
