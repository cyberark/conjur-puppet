require 'spec_helper'

describe 'conjur::secret', conjur: :mock do
  shared_examples "fetching secrets" do
    it "fetches the given variable using token from conjur class" do
      expect(subject.execute('key').unwrap).to eq 'variable value'
    end

    it "correctly encodes the id" do
      expect(subject.execute('tls/key').unwrap).to eq 'tls key value'
    end

    it "raises an error if the server returns one" do
      expect{subject.execute 'bad/tls/key'}.to raise_error Net::HTTPError
    end

    it "correctly encodes spaces" do
      expect(subject.execute('var with spaces').unwrap).to eq 'var with spaces value'
    end
  end

  ['Windows', 'RedHat'].each do |os_family|
    context "with #{os_family} platform" do
      let(:facts) { { os: { family: os_family } } }

      context "with Conjur v4 API" do
        before do
          allow_authorized_conjur_get('/api/variables/key/value') \
              .and_return http_ok 'variable value'
          allow_authorized_conjur_get('/api/variables/tls%2Fkey/value') \
              .and_return http_ok 'tls key value'
          allow_authorized_conjur_get('/api/variables/var+with+spaces/value') \
              .and_return http_ok 'var with spaces value'
          allow_authorized_conjur_get('/api/variables/bad%2Ftls%2Fkey/value') \
              .and_return http_unauthorized
        end
        include_examples "fetching secrets"
      end

      context "with Conjur v5 API" do
        let(:facts) {{ conjur_version: 5, os: { family: os_family } }}
        before do
          allow_authorized_conjur_get('/api/secrets/testacct/variable/key') \
              .and_return http_ok 'variable value'
          allow_authorized_conjur_get('/api/secrets/testacct/variable/tls%2Fkey') \
              .and_return http_ok 'tls key value'
          allow_authorized_conjur_get('/api/secrets/testacct/variable/var%20with%20spaces') \
              .and_return http_ok 'var with spaces value'
          allow_authorized_conjur_get('/api/secrets/testacct/variable/bad%2Ftls%2Fkey') \
              .and_return http_unauthorized
        end
        include_examples "fetching secrets"
      end
    end
  end
end
