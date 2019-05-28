require 'spec_helper'

describe 'conjur' do
  let(:site_pp_str) {} # can't find a better way to skip fixture manifests

  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) { { os: { family: os_family } } }

      context 'with api key' do
        let(:params) do {
          appliance_url: 'https://conjur.test/api',
          authn_login: 'host/test',
          authn_api_key: sensitive('the api key'),
          account: 'testacct',
          ssl_certificate: 'the cert goes here'
        } end

        before do
          allow_calling_puppet_function(:'conjur::token', :from_key) \
            .with(include('uri' => 'https://conjur.test/api/'), 'host/test', sensitive('the api key'), 'testacct')\
            .and_return sensitive('the token')
        end

        it "obtains token from the server" do
          expect(lookupvar('conjur::token')).to eq 'the token'
        end

        it "gets a default Conjur version" do
          expect(lookupvar('conjur::version')).to eq 5
        end

        it "stores the configuration and identity on the node" do
          if os_family == 'Windows'
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\ApplianceUrl')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\SslCertificate')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Account')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Version')

            expect(subject).to contain_wincred_credential('https://conjur.test/api/authn')
          else
            expect(subject).to contain_file('/etc/conjur.conf')
            expect(subject).to contain_file('/etc/conjur.identity')
          end
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

        before do
          allow_calling_puppet_function(:'conjur::manufacture_host', :create) \
              .with(include('uri' => 'https://conjur.test/api/'), 'test', sensitive('the host factory token'))\
              .and_return 'api_key' => sensitive('the api key'), 'id' => 'testacct:host:test'
          allow_calling_puppet_function(:'conjur::token', :from_key) \
              .with(include('uri' => 'https://conjur.test/api/'), 'host/test', sensitive('the api key'), 'testacct')\
              .and_return sensitive('the token')
        end

        it "creates the host using the host factory" do
          expect(lookupvar('conjur::token')).to eq 'the token'
        end

        it "stores the configuration and identity on the node" do
          if os_family == 'Windows'
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\ApplianceUrl')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Account')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Version')

            expect(subject).to contain_wincred_credential('https://conjur.test/api/authn')
          else
            expect(subject).to contain_file('/etc/conjur.conf')
            expect(subject).to contain_file('/etc/conjur.identity')

            # rspec-puppet parameter matchers don't work with some puppet versions
            expect(catalogue.resource('File[/etc/conjur.identity]').parameters).to include \
            content: matching(%r(machine https://conjur.test/api/authn\s+login host/test\s+password the api key)),
            mode: '0400'
          end
        end
      end

      context 'with preconfigured node' do
        let(:params) {{ authn_token: sensitive('just so it does not fail') }}
        let(:facts) do
          {
            conjur: {
              appliance_url: "https://conjur.fact.test/api",
              cert_file: "/etc/conjur.pem",
              ssl_certificate: "not really a cert"
            },
            os: { family: os_family }
          }
        end

        it "uses settings from facts" do
          expect(lookupvar('conjur::appliance_url')).to eq 'https://conjur.fact.test/api'
          expect(lookupvar('conjur::ssl_certificate')).to eq 'not really a cert'
        end
      end
    end
  end
end
