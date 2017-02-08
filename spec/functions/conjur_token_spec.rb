require 'spec_helper'

describe 'conjur_token', conjur: :mock do
  it "exchanges API key for token" do
    allow(conjur_connection).to receive(:post) \
        .with('/api/authn/users/alice/authenticate', 'the api key', nil) \
        .and_return http_ok 'the token'

    expect(subject.execute 'https://conjur.test/api', 'alice', 'the api key')\
        .to eq 'the token'
  end

  it "correctly encodes username" do
    allow(conjur_connection).to receive(:post) \
        .with('/api/authn/users/host%2Fpuppettest/authenticate', 'the api key', nil) \
        .and_return http_ok 'the host token'

    expect(subject.execute 'https://conjur.test/api', 'host/puppettest', 'the api key') \
        .to eq 'the host token'
  end

  it "raises error when server errors" do
    allow(conjur_connection).to receive(:post) \
        .with('/api/authn/users/alice/authenticate', 'the api key', nil) \
        .and_return http_unauthorized

    expect { subject.execute 'https://conjur.test/api', 'alice', 'the api key' } \
        .to raise_error Net::HTTPError
  end
end
