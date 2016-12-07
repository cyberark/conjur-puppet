FROM puppet/puppetserver

# Using the gem installer so that the code can go into the Puppet ruby installation.
RUN apt-get update && apt-get install -y build-essential jq vim

RUN mkdir -p /opt/puppetlabs/puppet/cache/jruby-gems
RUN puppetserver gem install -N conjur-cli -v5.3.0

# For release, this should be distributed as a module
COPY functions/* /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/functions/

COPY site.pp /etc/puppetlabs/code/environments/production/manifests/
