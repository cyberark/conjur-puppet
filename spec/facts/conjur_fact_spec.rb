require 'spec_helper'

describe 'conjur fact' do
  subject(:fact) { Facter.fact :conjur }
  before(:each) { Facter.clear }
  include FsMock
  
  it 'uses values from an existing configuration file' do
    mock_file '/etc/conjur.conf', """
      appliance_url: https://conjur.fact.test/api
      cert_file: /etc/conjur.pem
    """
    mock_file '/etc/conjur.pem', "not really a cert"
    
    expect(fact.value).to eq(
      "appliance_url" => "https://conjur.fact.test/api",
      "cert_file" => "/etc/conjur.pem",
      "ssl_certificate" => "not really a cert"
    )
  end
end
