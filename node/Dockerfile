FROM puppet/puppet-agent-ubuntu

# Using the gem installer so that the code can go into the Puppet ruby installation.
RUN apt-get update && apt-get install -y build-essential jq vim
RUN /opt/puppetlabs/puppet/bin/gem install -N conjur-cli --version 5.3.0

RUN mkdir -p /opt/facts
ENV FACTERLIB /opt/facts

COPY puppet.conf /etc/puppetlabs/puppet/puppet.conf
COPY conjur_token.rb /opt/facts
COPY conjur_layers.rb /opt/facts
COPY run.sh /

RUN ln -sf /etc/puppetlabs/puppet/conjur.yaml /root/.conjurrc

ENTRYPOINT [ "/run.sh" ]
