# frozen_string_literal: true

require 'spec_helper'

describe 'conjur::secret', conjur: :mock do
  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) do
        { os: { family: os_family } }
      end

      let(:cert_file) do
        cert_file = Tempfile.new('puppet_cert_file')
        cert_file.write 'ssl_certificate'
        cert_file.close

        cert_file
      end

      let(:account) { 'testacct' }
      let(:appliance_url) { 'https://conjur.test' }
      let(:authn_login) { 'authn_login' }
      let(:authn_api_key) { Puppet::Pops::Types::PSensitiveType::Sensitive.new('authn_api_key') }
      let(:ssl_certificate) { 'ssl_certificate' }
      let(:variable_id) { 'variable_id' }
      let(:version) { 5 }

      let(:mock_token) { 'myverysecrettoken' }
      let(:mock_client) { double('conjur_client') }

      let(:authn_path) { "authn/#{account}/#{authn_login}/authenticate" }
      let(:variable_path) { "secrets/#{account}/variable/#{variable_id}" }

      after(:each) do
        cert_file.unlink
      end

      shared_examples 'expected behavior' do
        it 'fetches the given variable' do
          expect(Conjur::PuppetModule::HTTP).to receive(:post)
            .with(appliance_url, authn_path, ssl_certificate, authn_api_key.unwrap)
            .and_return(mock_token)
          expect(Conjur::PuppetModule::HTTP).to receive(:get)
            .with(appliance_url, variable_path, ssl_certificate, mock_token)
            .and_return('variable value')

          actual_value = subject.execute(variable_id, options).unwrap
          expect(actual_value).to eq 'variable value'
        end

        it 'raises an error if the token is bad' do
          expect(Conjur::PuppetModule::HTTP).to receive(:post)
            .with(appliance_url, authn_path, ssl_certificate, authn_api_key.unwrap)
            .and_raise '403'

          expect {
            subject.execute(variable_id, options)
          }.to raise_error '403'
        end

        it 'raises an error if the variable is bad' do
          expect(Conjur::PuppetModule::HTTP).to receive(:post)
            .with(appliance_url, authn_path, ssl_certificate, authn_api_key.unwrap)
            .and_return(mock_token)
          expect(Conjur::PuppetModule::HTTP).to receive(:get)
            .with(appliance_url, variable_path, ssl_certificate, mock_token)
            .and_raise '404'

          expect {
            subject.execute(variable_id, options)
          }.to raise_error '404'
        end
      end

      describe 'using all parameters (server-side params)' do
        it 'raises error if authn_api_key is not Sensitive type' do
          options = {
            'authn_api_key' => 'just a string',
          }

          expect { subject.execute(variable_id, options) }.to raise_error \
            'Value of \'authn_api_key\' must be wrapped in \'Sensitive()\'!'
        end

        describe 'with ssl_certificate set' do
          let(:full_options) do
            {
              'appliance_url' => appliance_url,
              'account' => account,
              'authn_login' => authn_login,
              'authn_api_key' => authn_api_key,
              'ssl_certificate' => ssl_certificate,
            }
          end

          it_behaves_like 'expected behavior' do
            let(:options) { full_options }
          end

          it 'encodes the values correctly' do
            full_options['account'] = 'account!@#$%^&*()"\'[]{}:;'
            full_options['authn_login'] = 'login!@#$%^&*()"\'[]{}:;'
            variable_id = 'variable!@#$%^&*()"\'[]{}:;'
            expected_authn_path = 'authn' \
                                  '/account%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                                  '/login%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                                  '/authenticate'
            expected_var_path = 'secrets' \
                                '/account%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                                '/variable' \
                                '/variable%21%40%23%24%25%5E%26%2A%28%29%22%27%5B%5D%7B%7D%3A%3B'

            expect(Conjur::PuppetModule::HTTP).to receive(:post)
              .with(appliance_url, expected_authn_path, ssl_certificate, authn_api_key.unwrap)
              .and_return(mock_token)
            expect(Conjur::PuppetModule::HTTP).to receive(:get)
              .with(appliance_url, expected_var_path, ssl_certificate, mock_token)
              .and_return('variable value')

            actual_value = subject.execute(variable_id, full_options).unwrap
            expect(actual_value).to eq 'variable value'
          end
        end

        describe 'with cert_file set' do
          it_behaves_like 'expected behavior' do
            let(:options) do
              {
                'appliance_url' => appliance_url,
                'account' => account,
                'authn_login' => authn_login,
                'authn_api_key' => authn_api_key,
                'cert_file' => cert_file.path,
              }
            end
          end

          it 'raises error if cert file cannot be found' do
            options = {
              'appliance_url' => appliance_url,
              'account' => account,
              'authn_login' => authn_login,
              'authn_api_key' => authn_api_key,
              'cert_file' => '/bad/path',
            }

            expect { subject.execute(variable_id, options) }.to raise_error \
              'Cert file \'/bad/path\' cannot be found!'
          end
        end

        describe 'with ssl_certificate and cert_file set' do
          let(:full_options) do
            {
              'appliance_url' => appliance_url,
              'account' => account,
              'authn_login' => authn_login,
              'authn_api_key' => authn_api_key,
              'cert_file' => cert_file.path,
              'ssl_certificate' => 'this value is not used',
            }
          end

          it_behaves_like 'expected behavior' do
            let(:options) { full_options }
          end
        end
      end

      describe 'using default parameters (agent-side params)' do
        let(:mock_creds) { [authn_login, authn_api_key.unwrap] }
        let(:mock_config) do
          {
            'appliance_url' => appliance_url,
            'account' => account,
            'ssl_certificate' => ssl_certificate,
            'version' => version,
          }
        end

        before(:each) do
          allow(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          allow(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
                                                                 .and_return(mock_creds)
        end

        it_behaves_like 'expected behavior' do
          let(:options) { {} }
        end

        it 'encodes the values correctly' do
          mock_config['account'] = 'account!@#$%^&*()"\'[]{}:;'
          mock_creds = ['login!@#$%^&*()"\'[]{}:;', authn_api_key.unwrap]
          variable_id = 'variable!@#$%^&*()"\'[]{}:;'

          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          expect(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
                                                                  .and_return(mock_creds)
          expected_authn_path = 'authn' \
                                '/account%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                                '/login%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                                '/authenticate'
          expected_var_path = 'secrets' \
                              '/account%21%40%23%24%25%5E%26*%28%29%22%27%5B%5D%7B%7D%3A%3B' \
                              '/variable' \
                              '/variable%21%40%23%24%25%5E%26%2A%28%29%22%27%5B%5D%7B%7D%3A%3B'

          expect(Conjur::PuppetModule::HTTP).to receive(:post)
            .with(appliance_url, expected_authn_path, ssl_certificate, authn_api_key.unwrap)
            .and_return(mock_token)
          expect(Conjur::PuppetModule::HTTP).to receive(:get)
            .with(appliance_url, expected_var_path, ssl_certificate, mock_token)
            .and_return('variable value')

          actual_value = subject.execute(variable_id).unwrap
          expect(actual_value).to eq 'variable value'
        end

        it 'raises an error if creds cannot be retrieved' do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return({})
          expect { subject.execute(variable_id) }.to raise_error \
            'Conjur configuration not found on system'
        end

        it 'raises an error if config cannot be retrieved' do
          expect(Conjur::PuppetModule::Config).to receive(:load)
            .and_return(mock_config)
          expect(Conjur::PuppetModule::Identity).to receive(:load).with(mock_config)
                                                                  .and_return(nil)

          expect { subject.execute(variable_id) }.to raise_error \
            'Conjur identity not found on system'
        end
      end
    end
  end
end
