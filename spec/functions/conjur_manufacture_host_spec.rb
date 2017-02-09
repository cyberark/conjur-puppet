require 'spec_helper'

describe 'conjur_manufacture_host', conjur: :mock do
  it "creates a host and returns the description hash" do
    allow(conjur_connection).to receive(:post) \
        .with(anything, nil,
              "Authorization" => "Token token=\"hostfactorytokenn\"") \
    do |request_path|
      uri = URI request_path
      expect(uri.path).to eq '/api/host_factories/hosts'
      expect(URI.decode_www_form uri.query).to include(
        ['id', 'test+plus!'], ['annotations[puppet]', 'true'])
      http_ok '{ "api_key": "theapikey" }'
    end

    expect(subject.execute 'https://conjur.test/api', 'test+plus!', 'hostfactorytokenn')\
        .to eq "api_key" => 'theapikey'
  end
end
