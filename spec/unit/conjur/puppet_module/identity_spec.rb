# frozen_string_literal: true

require 'spec_helper'
require 'helpers/native_wincred'

require 'conjur/puppet_module/identity'

describe Conjur::PuppetModule::Identity do
  before(:each) do
    allow(Puppet.features).to receive(:microsoft_windows?).and_return(false)
  end

  describe 'from_file()' do
    it 'reads credentials from netrc' do
      Tempfile.open do |netrc|
        netrc.write <<~NETRC
          machine example.com
          login not-this-one
          password secretive

          machine conjur.test
          login conjur-login
          password secret
        NETRC
        netrc.close

        uri = URI('https://conjur.test/authn/foo')
        expect(described_class.from_file(uri, 'netrc_path' => netrc.path))
          .to eq ['conjur-login', 'secret']
      end
    end

    it 'warns when it cannot find matching credentials' do
      Tempfile.open do |netrc|
        netrc.write <<~NETRC
          machine example.com
          login not-this-one
          password secretive
        NETRC
        netrc.close

        uri = URI('https://conjur.test/authn/foo')

        expect(Puppet).to receive(:warning)
          .with %r{Could not find Conjur authentication info for host}
        expect(described_class.from_file(uri, 'netrc_path' => netrc.path)).to eq []
      end
    end
  end

  describe 'from_wincred()', wincred: :mock do
    before(:each) do
      allow(Puppet.features).to receive(:microsoft_windows?).and_return(true)
    end

    let(:wincred_credentials) do
      {
        # password needs an encoding
        'conjur.test' => ['conjur-login', 'secret'.encode('utf-16le').force_encoding('binary')],
      }
    end

    it 'reads credentials from wincred' do
      uri = URI('https://conjur.test/authn/foo')
      expect(described_class.from_wincred(uri)).to eq ['conjur-login', 'secret']
    end

    it 'warns when it cannot find matching credentials' do
      uri = URI('https://unknown-host.com')
      expect(Puppet).to receive(:warning)
        .with %r{Could not find any pre-populated Conjur credentials}
      expect(described_class.from_wincred(uri)).to eq []
    end
  end

  describe 'load()' do
    let(:appliance_url) { 'https://conjur.test/authn/foo' }
    let(:mock_identity) { double 'mock_identity' }
    let(:mock_uri) { double 'mock_uri' }
    let(:mock_config) do
      {
        'appliance_url' => appliance_url,
      }
    end

    it 'returns empty credentials and warns if there is no appliance url' do
      config = {
        foo: 'bar',
        baz: 'foo',
      }

      expect(Puppet).to receive(:warning)
        .with %r{Conjur identity cannot be found}
      expect(described_class.load(config)).to eq([])
    end

    before(:each) do
      allow(URI).to receive(:parse).with(appliance_url).and_return(mock_uri)
    end

    it 'uses Windows-specific config fetching on that platform' do
      allow(Puppet.features).to receive(:microsoft_windows?).and_return(true)

      expect(described_class).to receive(:from_wincred)
        .with(mock_uri).and_return(mock_identity)
      expect(described_class).not_to receive(:from_wincred)

      expect(described_class.load(mock_config)).to eq(mock_identity)
    end

    it 'uses Linux-specific config fetching on that platform' do
      expect(described_class).to receive(:from_file)
        .with(mock_uri, mock_config).and_return(mock_identity)
      expect(described_class).not_to receive(:from_wincred)

      expect(described_class.load(mock_config)).to eq(mock_identity)
    end
  end
end
