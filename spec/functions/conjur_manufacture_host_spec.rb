require 'spec_helper'

describe 'conjur_manufacture_host', conjur: :mock do
  it "creates a host and returns the description hash" do
    allow(conjur_connection).to receive(:post) \
        .with('/api/host_factories/hosts?id=test%2Bplus%21', anything,
              "Authorization" => "Token token=\"hostfactorytokenn\"") \
    do |_, content, _|
      expect(JSON.load(content)['annotations']).to include 'puppet' => true
      http_ok '{ "api_key": "theapikey" }'
    end

    expect(subject.execute 'https://conjur.test/api', 'test+plus!', 'hostfactorytokenn')\
        .to eq "api_key" => 'theapikey'
  end
end
