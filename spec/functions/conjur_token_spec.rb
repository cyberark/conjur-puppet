require 'spec_helper'

describe 'conjur::token', conjur: :mock do
  it "calls out to client" do
    client = { 'uri' => 'foo', 'version' => 5, 'cert' => 'foo' }
    expect(client).to receive(:authenticate).with('login', 'secret', 'account')
    subject.execute client, 'login', sensitive('secret'), 'account'
  end
end
