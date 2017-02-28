require 'spec_helper'

describe 'conjur::secret', conjur: :mock do
  it "fetches the given variable using token from conjur class" do
    expect_authorized_conjur_get('/api/variables/key/value') \
        .and_return http_ok 'variable value'
    expect(subject.execute('key').unwrap).to eq 'variable value'
  end

  it "correctly encodes the id" do
    expect_authorized_conjur_get('/api/variables/tls%2Fkey/value') \
        .and_return http_ok 'tls key value'
    expect(subject.execute('tls/key').unwrap).to eq 'tls key value'
  end


  it "raises an error if the server returns one" do
    expect_authorized_conjur_get('/api/variables/tls%2Fkey/value') \
        .and_return http_unauthorized
    expect{subject.execute 'tls/key'}.to raise_error Net::HTTPError
  end
end
