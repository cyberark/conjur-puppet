# frozen_string_literal: true

shared_context 'mock wincred', wincred: :mock do
  before(:each) do
    WinCred::Native.credentials = wincred_credentials
    allow(WinCred::Native).to receive(:CredFree).with(Fiddle::Pointer[0])
  end
end

module WinCred
  # Mock implementations of native methods.
  # Implementation details based directly on Microsoft documentation:
  # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/
  # Functionality limited to what is needed for testing.
  # The backend is a hash in .credentials where everything
  # is stored in UTF-8.
  module Native
    # Just the mock methods.
    # RSpec methods mixed in so we can set up expectations to make sure
    # memory is freed correctly (from the point of view of the library)
    # and we're not being called with something we're not implementing here.
    module Mock
      include RSpec::Matchers
      include RSpec::Mocks::ExampleMethods

      # :reek:Attribute
      attr_accessor :credentials

      # :reek:LongParameterList
      # :reek:UncommunicativeMethodName
      # :reek:TooManyStatements
      # rubocop:disable Naming/MethodName
      def CredReadW(target, type, flags, credential)
        expect([type, flags]).to eq [CRED_TYPE_GENERIC, 0]
        target = target.encode 'utf-8'

        return 0 unless (creds = credentials[target])

        VOIDP.new(credential).value =
          expect_free CREDENTIALW.malloc.fill target, creds
        1
      end

      # :reek:LongParameterList
      # :reek:UncommunicativeMethodName
      # :reek:TooManyStatements
      def CredEnumerateW(filter, flags, pcount, ppcredential)
        expect([filter, flags]).to eq [nil, 0]

        DWORD.new(pcount).value = count = credentials.length
        VOIDP.new(ppcredential).value =
          results = expect_free struct("CREDENTIALW * value[#{count}]").malloc

        results.value = malloc_credentials

        1
      end

      # converts credentials to CREDENTIALW and returns an
      # array of pointers to them
      def malloc_credentials
        credentials.map do |target, creds|
          CREDENTIALW.malloc.fill target, creds
        end
      end

      # Make sure the client code frees the result correctly.
      # Note we're leaking memory here by not freeing all the malloced
      # regions. This should be fine for tests.
      def expect_free(struct)
        struct.tap do
          expect(WinCred::Native).to receive(:CredFree).with(struct.to_ptr)
        end
      end

      # :reek:UncommunicativeMethodName
      def CredWriteW(credential, flags)
        expect(flags).to be 0
        credential = CREDENTIALW.new(credential).parse

        credentials[credential[:target].encode 'utf-8'] =
          [credential[:username].encode('utf-8'), credential[:password]]

        1
      end
      # rubocop:enable Naming/MethodName
    end

    # Make sure fiddle doesn't actually try to load the windows libs.
    # Note this will prevent running any tests against the actual libraries.
    # If such tests were to be added, a more sophisticated loading strategy
    # would be neede required.
    MOCKED_LIBS = ['Advapi32', 'kernel32'].freeze

    def self.dlload(*args)
      super(*(args - MOCKED_LIBS))
    end

    def self.extern(*_args)
      # noop, we're mocking the methods
    end

    require 'wincred/native'

    extend Mock

    # convenience structs
    VOIDP = struct 'void * value'
    DWORD = struct 'DWORD value'

    # Some extra convenience methods for this struct.
    # Note for testing we don't care about the memory being freed when
    # mallocing here.
    class CREDENTIALW
      # :reek:TooManyStatements
      def fill(target, creds)
        username, password = creds
        tap do
          self.TargetName = Fiddle::Pointer.malloc_zwstring target
          self.UserName = Fiddle::Pointer.malloc_zwstring username
          self.CredentialBlob = Fiddle::Pointer.malloc_zstring password
          self.CredentialBlobSize = password.size
        end
      end

      def parse
        {
          target: self.TargetName.as_zwstring,
          username: self.UserName.as_zwstring,
          password: self.CredentialBlob[0, self.CredentialBlobSize],
        }
      end
    end
  end
end

module Fiddle
  # add some utility methods
  class Pointer
    # get a zero-terminated wchar string
    def as_zwstring
      len = (0..32).find { |idx| self[idx * 2, 2] == "\0\0" }
      self[0, len * 2].force_encoding 'utf-16le'
    end

    # return a malloced wchar string
    def self.malloc_zwstring(string)
      string = (string + "\0").encode('utf-16le').force_encoding 'binary'
      len = string.length * 2
      Fiddle::Pointer.malloc(len).tap do |ptr|
        ptr[0, len] = string
      end
    end

    # return a malloced char string
    def self.malloc_zstring(string)
      string = (string + "\0").encode('utf-8').force_encoding 'binary'
      len = string.length
      Fiddle::Pointer.malloc(len).tap do |ptr|
        ptr[0, len] = string
      end
    end
  end
end
