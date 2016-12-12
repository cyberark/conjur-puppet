FROM puppet/puppetserver

# Using the gem installer so that the code can go into the Puppet ruby installation.
RUN apt-get update && apt-get install -y build-essential jq vim git

# RUN mkdir -p /opt/puppetlabs/puppet/cache/jruby-gems

# activesupport 5.0+ requires Ruby 2.2+
# RUN puppetserver gem install -N activesupport -v4.2.7.1
# RUN puppetserver gem install -N conjur-api

RUN cd /opt/puppetlabs/puppet/modules && git clone https://github.com/puppetlabs/puppetlabs-puppetserver_gem.git puppetserver_gem

COPY /conjur-api.pp /
RUN puppet apply /conjur-api.pp

# For release, this should be distributed as a module
COPY functions/* /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/functions/

COPY conjur.yaml /etc/puppetlabs/puppet/
