FROM ruby:2.4
MAINTAINER Conjur Inc

RUN mkdir /conjur
WORKDIR /conjur

COPY Gemfile /conjur/Gemfile
ARG PUPPET_VERSION
RUN env PUPPET_VERSION="$PUPPET_VERSION" bundle && cp Gemfile.lock /tmp

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

COPY . /conjur
