# frozen_string_literal: true

require 'spec_helper'
require 'helpers/fs'

require 'conjur/puppet_module/config'

describe Conjur::PuppetModule::Config do
  let(:cert_file) do
    cert_file = Tempfile.new('puppet_config_cert')
    cert_file.write 'mycert'
    cert_file.close

    cert_file
  end

  describe 'from_file' do
    let(:good_config_file) do
      config_file = Tempfile.new('puppet_config_conjurrc')
      config_file.write <<~CONFIG
        appliance_url: https://myserver:1234
        version: 123
        account: myaccount
        cert_file: #{cert_file.path}
      CONFIG
      config_file.close

      config_file
    end

    let(:bad_config_cert_path_file) do
      config_file = Tempfile.new('puppet_config_conjurrc')
      config_file.write <<~CONFIG
        appliance_url: https://myserver:1234
        version: 123
        account: myaccount
        cert_file: /does/not/exist
      CONFIG
      config_file.close

      config_file
    end

    after(:each) do
      cert_file.unlink
      good_config_file.unlink
      bad_config_cert_path_file.unlink
    end

    it 'returns empty config if config file is not found' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', '/no/config/file')

      expect(described_class.load).to eq({})
    end

    it 'reads config from file' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', good_config_file.path)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'cert_file' => cert_file.path,
                                         'ssl_certificate' => 'mycert',
                                         'version' => 123)
    end

    it 'throws error when cert file cannot be found' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', bad_config_cert_path_file.path)

      expect { described_class.load }.to \
        raise_error(RuntimeError, 'Cert file \'/does/not/exist\' cannot be found!')
    end
  end

  describe 'from_registry' do
    before(:each) do
      allow(subject).to receive(:load_registry_module)
      allow(Puppet.features).to receive(:microsoft_windows?).and_return(true)
    end

    it 'returns empty config if registry key name is not found' do
      expect(Puppet).to receive(:notice).with any_args

      # Win32::Registry class is awful and cannot be mocked easily
      class HKLM
        def open(_key)
          raise 'bad key'
        end
      end

      class MockClass
        HKEY_LOCAL_MACHINE = HKLM.new
      end

      stub_const('Win32::Registry', MockClass)

      expect(described_class.load).to eq({})
    end

    it 'loads registry entries correctly' do
      # Win32::Registry class is awful and cannot be mocked easily
      class HKLM
        ENTRIES = [
          ['Account', 'dummy', 'myaccount'],
          ['ApplianceUrl', 'dummy', 'https://myserver:1234'],
          ['SslCertificate', 'dummy', 'sslcert'],
          ['Version', 'dummy', 123],
        ].freeze

        def open(key)
          raise 'bad key' unless key == 'Software\CyberArk\Conjur'
          yield ENTRIES
        end
      end

      class MockClass
        HKEY_LOCAL_MACHINE = HKLM.new
      end

      stub_const('Win32::Registry', MockClass)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'ssl_certificate' => 'sslcert',
                                         'version' => 123)
    end
  end
end
