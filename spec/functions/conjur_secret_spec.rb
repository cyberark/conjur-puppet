require 'spec_helper'

describe 'conjur::secret', conjur: :mock do
  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) {{ os: { family: os_family } }}

      let(:account) { 'testacct'}
      let(:appliance_url) { 'https://conjur.test'}
      let(:authn_login) { 'authn_login' }
      let(:authn_api_key) { Puppet::Pops::Types::PSensitiveType::Sensitive.new("authn_api_key") }
      let(:ssl_certificate) { 'ssl_certificate' }
      let(:variable_id) { 'variable_id' }
      let(:version) { 5 }

      let(:mock_token) { double("token") }
      let(:mock_client) { double("conjur_client") }
      let(:mock_connection) { double("conjur_connection") }

      let(:authn_url) { "/authn/#{account}/#{authn_login}/authenticate" }

      before (:each) do
        allow_any_instance_of(Puppet::Pops::Functions::Function).to receive(:call_function)
          .with('conjur::client', appliance_url, version, ssl_certificate)
          .and_return(mock_client)

        allow(Net::HTTP).to receive(:start).with('conjur.test', 443, anything)
          .and_yield(mock_connection)

        allow(mock_client).to receive(:variable_value)
          .with(account, variable_id, mock_token)
          .and_return('variable value')
      end

      describe "with all parameters (server-side params)" do
        it "fetches the given variable using token from conjur class" do
          expect(mock_connection).to receive(:post).with(authn_url, authn_api_key.unwrap)
            .and_return(http_ok mock_token)

          actual_value = subject.execute(variable_id,
                                         appliance_url,
                                         account,
                                         authn_login,
                                         authn_api_key,
                                         ssl_certificate).unwrap
          expect(actual_value).to eq 'variable value'
        end

        it "raises an error if the token is bad" do
          expect(mock_connection).to receive(:post).with(authn_url, authn_api_key.unwrap)
            .and_return(http_unauthorized)

          expect {
            subject.execute(variable_id,
                            appliance_url,
                            account,
                            authn_login,
                            authn_api_key,
                            ssl_certificate) }.to raise_error Net::HTTPError
        end
      end

      describe "with default parameter (agent-side params)" do
        let(:mock_creds) { [authn_login, authn_api_key.unwrap] }
        let(:mock_config) {
          {
            'appliance_url' => appliance_url,
            'account' => account,
            'ssl_certificate' => ssl_certificate,
            'version' => version,
          }
        }

        it "raises an error if creds can't be retrieved" do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return({})
          expect { subject.execute(variable_id) }.to raise_error \
            'Conjur configuration not found on system'
        end

        it "raises an error if config can't be retrieved" do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          expect(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
            .and_return(nil)

          expect { subject.execute(variable_id) }.to raise_error \
            'Conjur identity not found on system'
        end

        it "fetches the given variable using token from conjur class" do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          expect(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
            .and_return(mock_creds)

          expect(mock_connection).to receive(:post).with(authn_url, authn_api_key.unwrap)
            .and_return(http_ok mock_token)

          expect(subject.execute(variable_id).unwrap).to eq 'variable value'
        end

        it "raises an error if the token is bad" do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          expect(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
            .and_return(mock_creds)

          expect(mock_connection).to receive(:post).with(authn_url, authn_api_key.unwrap)
            .and_return(http_unauthorized)

          expect { subject.execute(variable_id) }.to raise_error Net::HTTPError
        end
      end
    end
  end
end
