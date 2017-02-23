require 'spec_helper'
describe 'conjur' do
  context 'with api key' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_login: 'host/test',
      authn_api_key: 'the api key',
    } end

    it "obtains token from the server" do
      allow_calling_puppet_function(:'conjur::token', :from_key) \
          .with(include('uri' => 'https://conjur.test/api'), 'host/test', 'the api key')\
          .and_return 'the token'
      expect(lookupvar('conjur::token')).to eq 'the token'
    end
  end

  context 'with provided token' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_token: 'the provided token'
    } end

    it "uses the provided token" do
      expect(lookupvar('conjur::token')).to eq 'the provided token'
    end
  end

  context 'with host factory token' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_login: 'host/test',
      host_factory_token: 'the host factory token',
    } end

    it "creates the host using the host factory" do
      allow_calling_puppet_function(:'conjur::manufacture_host', :create) \
          .with(include('uri' => 'https://conjur.test/api'), 'test', 'the host factory token')\
          .and_return 'api_key' => 'the api key'
      allow_calling_puppet_function(:'conjur::token', :from_key) \
          .with(include('uri' => 'https://conjur.test/api'), 'host/test', 'the api key')\
          .and_return 'the token'
      expect(lookupvar('conjur::token')).to eq 'the token'
    end
  end
end
