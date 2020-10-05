# frozen_string_literal: true

require 'spec_helper'

require 'puppet/functions/conjur/util/config'

describe Conjur::PuppetModule::Config do
  let(:cert_file) do
    cert_file = Tempfile.new('puppet_config_cert')
    cert_file.write 'myfilecert'
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

    let(:good_config_file_ssl_certificate) do
      config_file = Tempfile.new('puppet_config_conjurrc')
      config_file.write <<~CONFIG
        appliance_url: https://myserver:1234
        version: 123
        account: myaccount
        ssl_certificate: mycert
      CONFIG
      config_file.close

      config_file
    end

    let(:good_config_file_ssl_certificate_and_cert_path) do
      config_file = Tempfile.new('puppet_config_conjurrc')
      config_file.write <<~CONFIG
        appliance_url: https://myserver:1234
        version: 123
        account: myaccount
        ssl_certificate: mycert
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
      good_config_file_ssl_certificate.unlink
      bad_config_cert_path_file.unlink
    end

    it 'returns empty config if config file is not found' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', '/no/config/file')

      expect(described_class.load).to eq({})
    end

    it 'returns error if cert file cannot be found' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', bad_config_cert_path_file.path)

      expect { described_class.load }.to raise_error %r{cannot be found}
    end

    it 'reads config from file (cert_file)' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH', good_config_file.path)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'cert_file' => cert_file.path,
                                         'ssl_certificate' => 'myfilecert',
                                         'version' => 123)
    end

    it 'reads config from file (ssl_certificate)' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH',
                 good_config_file_ssl_certificate.path)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'ssl_certificate' => 'mycert',
                                         'version' => 123)
    end

    it 'prioritizes cert_file config' do
      stub_const('Conjur::PuppetModule::Config::CONFIG_FILE_PATH',
                 good_config_file_ssl_certificate_and_cert_path.path)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'cert_file' => cert_file.path,
                                         'ssl_certificate' => 'myfilecert',
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

      class HKLM
        def initialize(entries)
          @entries = entries
        end

        def open(key)
          raise 'bad key' unless key == 'Software\CyberArk\Conjur'
          # rubocop:disable RSpec/InstanceVariable
          yield @entries
        end
      end
    end

    it 'returns empty config if registry key name is not found' do
      expect(Puppet).to receive(:notice).with any_args

      # Win32::Registry class is awful and cannot be mocked easily
      class NoEntryHKLM
        def open(_key)
          raise 'bad key'
        end
      end

      class MockRegistry
        HKEY_LOCAL_MACHINE = NoEntryHKLM.new
      end

      stub_const('Win32::Registry', MockRegistry)

      expect(described_class.load).to eq({})
    end

    it 'loads registry entries correctly (cert_file)' do
      ENTRIES = [
        ['Account', 'dummy', 'myaccount'],
        ['ApplianceUrl', 'dummy', 'https://myserver:1234'],
        ['CertFile', 'dummy', cert_file.path],
        ['Version', 'dummy', 123],
      ].freeze

      class MockRegistry
        HKEY_LOCAL_MACHINE = HKLM.new(ENTRIES)
      end

      stub_const('Win32::Registry', MockRegistry)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'cert_file' => cert_file.path,
                                         'ssl_certificate' => 'myfilecert',
                                         'version' => 123)
    end

    it 'loads registry entries correctly (ssl_certificate)' do
      ENTRIES = [
        ['Account', 'dummy', 'myaccount'],
        ['ApplianceUrl', 'dummy', 'https://myserver:1234'],
        ['SslCertificate', 'dummy', 'sslcert'],
        ['Version', 'dummy', 123],
      ].freeze

      class MockRegistry
        HKEY_LOCAL_MACHINE = HKLM.new(ENTRIES)
      end

      stub_const('Win32::Registry', MockRegistry)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'ssl_certificate' => 'sslcert',
                                         'version' => 123)
    end

    it 'prioritizes CertFile config' do
      ENTRIES = [
        ['Account', 'dummy', 'myaccount'],
        ['ApplianceUrl', 'dummy', 'https://myserver:1234'],
        ['CertFile', 'dummy', cert_file.path],
        ['SslCertificate', 'dummy', 'this should not get used'],
        ['Version', 'dummy', 123],
      ].freeze

      class MockRegistry
        HKEY_LOCAL_MACHINE = HKLM.new(ENTRIES)
      end

      stub_const('Win32::Registry', MockRegistry)

      expect(described_class.load).to eq('account' => 'myaccount',
                                         'appliance_url' => 'https://myserver:1234',
                                         'cert_file' => cert_file.path,
                                         'ssl_certificate' => 'myfilecert',
                                         'version' => 123)
    end

    it 'throws error when cert file cannot be found' do
      ENTRIES = [
        ['Account', 'dummy', 'myaccount'],
        ['ApplianceUrl', 'dummy', 'https://myserver:1234'],
        ['CertFile', 'dummy', '/does/not/exist'],
        ['Version', 'dummy', 123],
      ].freeze

      class MockRegistry
        HKEY_LOCAL_MACHINE = HKLM.new(ENTRIES)
      end

      stub_const('Win32::Registry', MockRegistry)

      expect { described_class.load }.to \
        raise_error(RuntimeError, 'Cert file \'/does/not/exist\' cannot be found!')
    end
  end
end
