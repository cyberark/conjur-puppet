FROM ruby:2.2.3
MAINTAINER Conjur Inc

RUN mkdir /src
WORKDIR /src

COPY Gemfile /src/Gemfile
RUN bundle

COPY . /src
