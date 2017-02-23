require 'spec_helper'

describe 'conjur fact' do
  include FsMock
  subject!(:fact) { Facter.fact :conjur }

  before do
    mock_file '/etc/conjur.conf', """
      appliance_url: https://conjur.fact.test/api
      cert_file: /etc/conjur.pem
    """
    mock_file '/etc/conjur.pem', "not really a cert"
  end

  it "reads appliance url and cert" do
    expect(fact.value['appliance_url']).to eq 'https://conjur.fact.test/api'
    expect(fact.value['ssl_certificate']).to eq 'not really a cert'
  end
end
