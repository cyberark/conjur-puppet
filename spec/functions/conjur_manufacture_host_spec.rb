require 'spec_helper'

describe 'conjur_manufacture_host', conjur: :mock do
  it "creates a host and returns the description hash" do
    allow(conjur_connection).to receive(:post) \
        .with('/api/host_factories/hosts?id=test%2Bplus%21', nil,
              "Authorization" => "Token token=\"hostfactorytokenn\"") \
        .and_return http_ok '{ "api_key": "theapikey" }'

    expect(subject.execute 'https://conjur.test/api', 'test+plus!', 'hostfactorytokenn')\
        .to eq "api_key" => 'theapikey'
  end
end
