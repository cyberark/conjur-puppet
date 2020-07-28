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

            expect(subject).to contain_credential('conjur.test')
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
          authn_login: authn_login,
          host_factory_token: sensitive('the host factory token'),
        } end

        it "creates the host using the host factory" do
          expect(lookupvar('conjur::token')).to eq 'the token'
        end

        it "stores the configuration and identity on the node" do
          if os_family == 'Windows'
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\ApplianceUrl')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Account')
            expect(subject).to contain_registry_value('HKLM\Software\CyberArk\Conjur\Version')

            expect(subject).to contain_credential('conjur.test')
          else
            expect(subject).to contain_file('/etc/conjur.conf')
            expect(subject).to contain_file('/etc/conjur.identity')

            # rspec-puppet parameter matchers don't work with some puppet versions
            expect(catalogue.resource('File[/etc/conjur.identity]').parameters).to include \
              content: matching(Regexp.new(
                "machine https://conjur.test/api/authn" \
                "\\s+login #{authn_login}" \
                "\\s+password the api key"
              )),
              mode: '0400'
          end
        end

        let(:hostname) { 'test' }
        let(:authn_login) { ['host', hostname].join '/' }

        before do
          allow_calling_puppet_function(:'conjur::manufacture_host', :create)
            .with(
              include('uri' => 'https://conjur.test/api/'), hostname,
              sensitive('the host factory token')
            ).and_return(
              'api_key' => sensitive('the api key'),
              'id' => 'testacct:host:test'
            )
          allow_calling_puppet_function(:'conjur::token', :from_key)
            .with(
              include('uri' => 'https://conjur.test/api/'), authn_login,
              sensitive('the api key'), 'testacct'
            ).and_return sensitive('the token')
        end

        context "with host name containing a slash" do
          let(:hostname) { 'staging/foo1' }
          it "creates the host correctly" do
            expect(lookupvar('conjur::token')).to eq 'the token'
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
          expect(lookupvar('conjur::raw_ssl_certificate')).to eq 'not really a cert'
        end
      end
    end
  end

  context 'ssl certificate params' do
    # Setting the os family fact to 'Windows' below results in the cert_file not being
    # found. This seems to be because the call to `file()` in the conjur module's
    # `init.pp` is somehow being interpreted as being run on a Windows machine and so the
    # unix path provided below fails absolute path validation. This seems to be an issue
    # with the rspec utilities that simulate the generation of the catalog, as opposed to
    # any logic in `init.pp`. Under production circumstances the call to `file()` will
    # always be run on a unix machine (the Puppet server) and so would never fail the
    # absolute path validation.
    #
    # This issue is unfortunate because it prevents us from having the useful
    # platform-specific test assertion to ensure that the contents of
    # `conjur::raw_ssl_certificate` are stored on the node alongside other machine
    # identity values.
    let(:facts) { { os: { family: 'AnythingButWindows' } } }

    context 'with cert_file param' do
      let(:params) do {
          appliance_url: 'https://conjur.test/api',
          authn_token: sensitive('so that it does not error on token'),
          cert_file: '/conjur/spec/fixtures/conjur-ca.pem'
      } end

      it "uses the provided ssl certificate" do
        expect(lookupvar('conjur::raw_ssl_certificate')).to eq 'definitely a ca'
      end
    end

    context 'with ssl_certificate param' do
      let(:params) do {
          appliance_url: 'https://conjur.test/api',
          authn_token: sensitive('so that it does not error on token'),
          ssl_certificate: 'raw contents of the cert',
      } end

      it "uses the provided ssl certificate" do
        expect(lookupvar('conjur::raw_ssl_certificate')).to eq 'raw contents of the cert'
      end
    end

    context 'with cert_file and ssl_certificate params' do
      let(:params) do {
          appliance_url: 'https://conjur.test/api',
          authn_token: sensitive('so that it does not error on token'),
          ssl_certificate: 'will be overridden',
          cert_file: '/conjur/spec/fixtures/conjur-ca.pem'
      } end

      it "uses ssl certificate from cert_file" do
        expect(lookupvar('conjur::raw_ssl_certificate')).to eq 'definitely a ca'
      end
    end
  end
end
