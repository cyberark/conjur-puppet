# frozen_string_literal: true

require 'spec_helper'
require 'helpers/native_wincred'

require 'wincred/wincred'

describe WinCred, wincred: :mock do
  let(:wincred_credentials) do
    {
      'some.test' => %w(alice secret),
      'other.test' => %w(bob password)
    }
  end

  describe '.exist?' do
    it 'checks whether an entry exists' do
      expect(WinCred.exist?('another.test')).to be false
      expect(WinCred.exist?('some.test')).to be true
    end
  end

  describe '.enumerate_credentials' do
    it 'enumerates all credentials' do
      expect(WinCred.enumerate_credentials).to eq [
        { target: 'some.test', username: 'alice', value: 'secret' },
        { target: 'other.test', username: 'bob', value: 'password' }
      ]
    end
  end

  describe '.write_credential' do
    it 'writes given credential' do
      WinCred.write_credential \
        target: 'write.test', username: 'eve', value: 'evil'
      expect(wincred_credentials['write.test']).to eq %w(eve evil)
    end
  end

  describe '.read_credential' do
    it 'reads a given credential' do
      expect(WinCred.read_credential('some.test')).to eq \
        target: 'some.test', username: 'alice', value: 'secret'
    end
  end

  context 'with UTF-16 encoded credentials' do
    it 'round-trips them correctly' do
      password = 'ancient'.encode('utf-16le').force_encoding('binary')
      WinCred.write_credential \
        target: 'utf16.test', username: 'ursula', value: password
      expect(WinCred.read_credential('utf16.test')).to eq \
        target: 'utf16.test', username: 'ursula', value: password
    end
  end
end
