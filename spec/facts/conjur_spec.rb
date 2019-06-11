# frozen_string_literal: true

require 'spec_helper'

describe 'conjur fact' do
  include FsMock
  subject!(:fact) { Facter.fact :conjur }
  before(:each) { Facter.clear }

  before do
    mock_file '/etc/conjur.conf', "
      appliance_url: https://conjur.fact.test/api
      cert_file: /etc/conjur.pem
    "
    mock_file '/etc/conjur.pem', "not really a cert"

    file_identity = %w(myuser myapikey)

    allow(Conjur::PuppetModule::Identity).to receive(:from_file)
      .and_return(file_identity)
  end

  it "reads appliance url and cert" do
    expect(fact.value).to eq(
      "appliance_url" => "https://conjur.fact.test/api",
      "cert_file" => "/etc/conjur.pem",
      "ssl_certificate" => "not really a cert",
      "authn_login" => "myuser"
    )
  end

  context 'when the platform is Windows' do
    before do
      Puppet.features.stub(:microsoft_windows?) { true }

      registry_values = {
        "appliance_url" => "https://conjur.fact.test/api",
        "ssl_certificate" => "not really a cert"
      }

      allow(Conjur::PuppetModule::Config).to receive(:from_registry)
        .and_return(registry_values)

      wincred_value = %w(myuser myapikey)

      allow(Conjur::PuppetModule::Identity).to receive(:from_wincred)
        .and_return(wincred_value)
    end

    it 'uses config values from Registry' do
      expect(fact.value).to eq(
        "appliance_url" => "https://conjur.fact.test/api",
        "ssl_certificate" => "not really a cert",
        "authn_login" => "myuser"
      )
    end
  end
end
