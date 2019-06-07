# frozen_string_literal: true

require 'spec_helper'
require 'helpers/fs'

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
  include FsMock
end
