# frozen_string_literal: true

require 'spec_helper'
require 'helpers/fs'
require 'helpers/native_wincred'

require 'conjur/puppet_module/identity'

describe Conjur::PuppetModule::Identity do
  describe '.from_file' do
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

        expect(Conjur::PuppetModule::Identity.from_file(
            URI('https://conjur.test/authn/foo'), 'netrc_path' => netrc.path
        )).to eq %w(conjur-login secret)
      end
    end
  end

  describe '.from_wincred', wincred: :mock do
    before { Puppet.features.stub(:microsoft_windows?) { true } }

    let(:wincred_credentials) do
      {
          # password needs an encoding
          'conjur.test' => ["conjur-login", "secret".encode('utf-16le').force_encoding('binary')]
      }
    end

    it 'reads credentials from wincred' do
      expect(Conjur::PuppetModule::Identity.from_wincred(
          URI('https://conjur.test/authn/foo')
      )).to eq %w(conjur-login secret)
    end
  end

  include FsMock
end
