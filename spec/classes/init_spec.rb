require 'spec_helper'
describe 'conjur' do
  context 'with default values for all parameters' do
    it { should contain_class('conjur') }
  end

  context 'with api key' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_login: 'host/test',
      authn_api_key: 'the api key',
    } end

    it "obtains token from the server" do
      allow_calling_puppet_function(:conjur_token) \
          .with(['https://conjur.test/api', 'host/test', 'the api key'])\
          .and_return 'the token'
      expect(lookupvar('$conjur::token')).to eq 'the token'
    end
  end

  context 'with provided token' do
    let(:params) do {
      authn_token: 'the provided token'
    } end

    it "uses the provided token" do
      expect(lookupvar('$conjur::token')).to eq 'the provided token'
    end
  end
end
