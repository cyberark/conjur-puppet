FROM ruby:2.4
MAINTAINER Conjur Inc

RUN mkdir /conjur
WORKDIR /conjur

COPY Gemfile /conjur/Gemfile
ARG PUPPET_VERSION

ENV PUPPET_VERSION="$PUPPET_VERSION"

# The `Gemfile.lock` created here at build time is stored as `/build-Gemfile.lock` for
# safe-keeping. `/docker-entrypoint.sh` will copy this file into the working directory,
# `/conjur/Gemfile.lock`, at runtime to prevent any issues associated with it being
# overwritten by a volume mount of the `/conjur` working directory.
RUN bundle && cp Gemfile.lock /build-Gemfile.lock

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

COPY . /conjur
