require 'spec_helper'

describe 'conjur' do
  context 'with api key' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_login: 'host/test',
      authn_api_key: sensitive('the api key'),
    } end

    it "obtains token from the server" do
      allow_calling_puppet_function(:'conjur::token', :from_key) \
          .with(include('uri' => 'https://conjur.test/api'), 'host/test', sensitive('the api key'))\
          .and_return sensitive('the token')
      expect(lookupvar('conjur::token')).to eq sensitive('the token')
    end
  end

  context 'with provided token' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_token: sensitive('the provided token')
    } end

    it "uses the provided token" do
      expect(lookupvar('conjur::token.unwrap')).to eq 'the provided token'
    end
  end

  context 'with host factory token' do
    let(:params) do {
      appliance_url: 'https://conjur.test/api',
      authn_login: 'host/test',
      host_factory_token: sensitive('the host factory token'),
    } end

    it "creates the host using the host factory" do
      allow_calling_puppet_function(:'conjur::manufacture_host', :create) \
          .with(include('uri' => 'https://conjur.test/api'), 'test', sensitive('the host factory token'))\
          .and_return 'api_key' => sensitive('the api key')
      allow_calling_puppet_function(:'conjur::token', :from_key) \
          .with(include('uri' => 'https://conjur.test/api'), 'host/test', sensitive('the api key'))\
          .and_return sensitive('the token')
      expect(lookupvar('conjur::token')).to eq sensitive('the token')
    end
  end

  context 'with preconfigured node' do
    let(:params) {{ authn_token: sensitive('just so it does not fail') }}
    let(:facts) {{ conjur: Facter.fact(:conjur).value }}

    include FsMock
    before do
      mock_file '/etc/conjur.conf', """
        appliance_url: https://conjur.fact.test/api
        cert_file: /etc/conjur.pem
      """
      mock_file '/etc/conjur.pem', "not really a cert"
    end

    it "uses settings from facts" do
      expect(lookupvar('conjur::appliance_url')).to eq 'https://conjur.fact.test/api'
      expect(lookupvar('conjur::ssl_certificate')).to eq 'not really a cert'
    end
  end
end
