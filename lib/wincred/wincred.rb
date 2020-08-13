# rubocop:disable Style/FrozenStringLiteralComment

require_relative './conversion'
require_relative './native'

# This module provides a high-level API for interations with the Windows Credential
# Manager
module WinCred
  class << self
    def exist?(target)
      cred_ptr = Fiddle::Pointer.new 0

      read_result = Native.CredReadW(
        target.encode('utf-16le'),
        Native::CRED_TYPE_GENERIC,
        Native::FLAGS_NONE,
        cred_ptr.ref,
      )

      read_result.positive?
    ensure
      Native.CredFree(cred_ptr) if cred_ptr
    end

    def enumerate_credentials
      pp_credentials = Fiddle::Pointer.new 0

      # Create 4-byte integer pointer to hold the returned cred count
      cred_count_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_LONG, Fiddle::RUBY_FREE)

      enum_result = Native.CredEnumerateW(
        nil,
        Native::FLAGS_NONE,
        cred_count_ptr,
        pp_credentials.ref,
      )

      if enum_result.zero?
        raise "Enumerate credentials in WinCred failed. Error code: #{Native.GetLastError}"
      end

      # Convert count bytes to Ruby int
      count = cred_count_ptr[0, 4].unpack('L').first

      # Convert memory struct array into Ruby array
      # RuboCop disabled rule here may be a valid find but this code is very fragile
      # and old.
      # rubocop:disable Performance/TimesMap
      count.times.map do |ndx|
        cred_ptr = (pp_credentials + (ndx * Fiddle::SIZEOF_VOIDP)).ptr
        cred = Native::CREDENTIALW.new(cred_ptr)
        cred_to_hash(cred)
      end
    ensure
      # Free the credential memory
      Native.CredFree(pp_credentials) if pp_credentials
    end

    def write_credential(
        target:,
        username:,
        value: # binary string
    )

      if value.bytes.size != value.size
        raise "Write to WinCred failed. Value is not a binary string. Encoding is (#{value.encoding})."
      end

      cred = Native::CREDENTIALW.malloc

      cred.Flags = Native::FLAGS_NONE
      cred.Type = Native::CRED_TYPE_GENERIC
      cred.TargetName = target.encode('utf-16le')
      cred.Comment = ''
      cred.CredentialBlobSize = value.size
      cred.CredentialBlob = Fiddle::Pointer[value]
      cred.Persist = Native::CRED_PERSIST_LOCAL_MACHINE
      cred.AttributeCount = 0
      cred.Attributes = nil
      cred.TargetAlias = nil
      cred.UserName = username.encode('utf-16le')

      write_result = Native.CredWriteW(Fiddle::Pointer[cred], 0)

      raise "Write to WinCred failed. Error code: #{Native.GetLastError}" if write_result.zero?
    ensure
      Fiddle.free(cred.to_i) if cred
    end

    def read_credential(target)
      cred_ptr = Fiddle::Pointer.new 0

      # We have to encode the target name for the Windows API call
      read_result = Native.CredReadW(
        target.encode('utf-16le'),
        Native::CRED_TYPE_GENERIC,
        Native::FLAGS_NONE,
        cred_ptr.ref,
      )

      raise "Read from WinCred failed. Error code: #{Native.GetLastError}" if read_result.zero?

      cred = Native::CREDENTIALW.new(cred_ptr)
      cred_to_hash(cred)
    ensure
      Native.CredFree(cred_ptr) if cred_ptr
    end

    def delete_credential(target)
      delete_result = Native.CredDeleteW(
        target.encode('utf-16le'),
        Native::CRED_TYPE_GENERIC,
        Native::FLAGS_NONE,
      )

      raise "Delete from WinCred failed. Error code: #{Native.GetLastError}" if delete_result.zero?
    end

    private

    def cred_to_hash(cred)
      {
        target: Conversion.pwchar_to_str(cred.TargetName).encode('utf-8'),
        username: Conversion.pwchar_to_str(cred.UserName).encode('utf-8'),
        value: (cred.CredentialBlobSize.positive? ? cred.CredentialBlob.to_str(cred.CredentialBlobSize) : nil),
      }
    end
  end
end
