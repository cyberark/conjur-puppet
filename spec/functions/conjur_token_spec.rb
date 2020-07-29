require 'spec_helper'

describe 'conjur::token', conjur: :mock do
  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) { { os: { family: os_family } } }

      it "calls out to client" do
        client = { 'uri' => 'foo', 'version' => 5, 'cert' => 'foo' }
        client.define_singleton_method(:freeze) {} # to avoid rspec warnings
        expect(client).to receive(:authenticate).with('login', 'secret', 'account')
        subject.execute client, 'login', sensitive('secret'), 'account'
      end
    end
  end
end
