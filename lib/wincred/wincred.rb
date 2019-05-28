require 'fiddle/import'
require 'fiddle/types'

module WinCred
  class << self
    def exist?(target)
      cred_ptr = Fiddle::Pointer.new 0

      read_result = Native.CredReadW(
        target.encode('utf-16le'),
        Native::CRED_TYPE_GENERIC,
        Native::FLAGS_NONE,
        cred_ptr.ref
      )

      read_result > 0
    ensure
      Native.CredFree(cred_ptr) if cred_ptr
    end

    def enumerate_credentials
      pp_credentials = Fiddle::Pointer.new 0

      # Create 4-byte integer pointer to hold the returned cred count
      free = Fiddle::Function.new(Fiddle::RUBY_FREE, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
      cred_count_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_LONG, free)

      enum_result = Native.CredEnumerateW(
        nil,
        Native::FLAGS_NONE,
        cred_count_ptr,
        pp_credentials.ref
      )

      if enum_result.zero?
        raise "Enumerate credentials in WinCred failed. Error code: #{Native.GetLastError}" 
      end

      # Convert count bytes to Ruby int
      count = cred_count_ptr[0, 4].unpack('L').first

      # Convert memory struct array into Ruby array
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
        value:
      )
      # Convert the unicode string to a byte array
      value_blob = value.encode('utf-8').unpack('c*')

      cred = Native::CREDENTIALW.malloc

      cred.Flags = Native::FLAGS_NONE
      cred.Type = Native::CRED_TYPE_GENERIC
      cred.TargetName = target.encode('utf-16le')
      cred.Comment = ''
      cred.CredentialBlobSize = value_blob.size
      cred.CredentialBlob = Fiddle::Pointer[value_blob.pack('c*')]
      cred.Persist = Native::CRED_PERSIST_LOCAL_MACHINE
      cred.AttributeCount = 0
      cred.Attributes = nil
      cred.TargetAlias = nil
      cred.UserName = username.encode('utf-16le')

      write_result = Native.CredWriteW(Fiddle::Pointer[cred], 0)

      raise "Write to WinCred failed. Error code: #{Native.GetLastError}" if write_result.zero?
    ensure
      Native.CredFree(cred) if cred
    end

    def read_credential(target)
      cred_ptr = Fiddle::Pointer.new 0

      # We have to encode the target name for the Windows API call
      read_result = Native.CredReadW(
        target.encode('utf-16le'),
        Native::CRED_TYPE_GENERIC,
        Native::FLAGS_NONE,
        cred_ptr.ref
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
        Native::FLAGS_NONE
      )

      raise "Delete from WinCred failed. Error code: #{Native.GetLastError}" if delete_result.zero?
    end

    private

    def cred_to_hash(cred)
      {
        target: read_wide_string(cred.TargetName),
        username: read_wide_string(cred.UserName),
        value: (cred.CredentialBlobSize > 0 ? cred.CredentialBlob.to_s : nil)
      }
    end

    def read_wide_string(ptr)
      idx = 0
      str = ''
      while ptr[idx, 2] != "\0\0"
        str += ptr[idx, 2].force_encoding('UTF-16LE').encode('UTF-8')
        idx += 2
      end
      str
    end
  end

  module Native
    extend Fiddle::Importer
    dlload 'Advapi32', 'kernel32'

    include Fiddle::Win32Types

    typealias 'LPBYTE', 'BYTE*'
    typealias 'LPWSTR', 'wchar_t*'
    typealias 'LPCWSTR', 'const wchar_t*'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/ns-wincred-credential_attributew
    CREDENTIAL_ATTRIBUTEW = struct(
      [
        'LPWSTR    Keyword',
        'DWORD      Flags',
        'DWORD      ValueSize',
        'LPBYTE     Value'
      ]
    )
    typealias 'PCREDENTIAL_ATTRIBUTEW', 'CREDENTIAL_ATTRIBUTEW*'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/ns-wincred-credentialw
    CREDENTIALW = struct(
      [
        'DWORD                 Flags',
        'DWORD                 Type',
        'LPWSTR                TargetName',
        'LPWSTR                Comment',

        # https://docs.microsoft.com/en-us/windows/desktop/api/minwinbase/ns-minwinbase-filetime
        'DWORD                  LastWritten_dwLowDateTime',
        'DWORD                  LastWritten_dwHighDateTime',

        'DWORD                  CredentialBlobSize',
        'LPBYTE                 CredentialBlob',
        'DWORD                  Persist',
        'DWORD                  AttributeCount',
        'PCREDENTIAL_ATTRIBUTEW Attributes',
        'LPWSTR                 TargetAlias',
        'LPWSTR                 UserName'
      ]
    )
    typealias 'PCREDENTIALW', 'CREDENTIALW*'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/nf-wincred-credwritew
    #
    # BOOL CredWriteW(
    #   PCREDENTIALW Credential,
    #   DWORD        Flags
    # );
    extern 'BOOL CredWriteW(PCREDENTIALW, DWORD)'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/nf-wincred-credreadw
    #
    # BOOL CredReadW(
    #   LPCWSTR      TargetName,
    #   DWORD        Type,
    #   DWORD        Flags,
    #   PCREDENTIALW *Credential
    # );
    extern 'BOOL CredReadW(LPCWSTR, DWORD, DWORD, PCREDENTIALW*)'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/nf-wincred-credenumeratew
    # BOOL CredEnumerateW(
    #   LPCWSTR      Filter,
    #   DWORD        Flags,
    #   DWORD        *Count,
    #   PCREDENTIALW **Credential
    # );
    extern 'BOOL CredEnumerateW(LPCWSTR, DWORD, DWORD*, PCREDENTIALW**)'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/nf-wincred-creddeletew
    #
    # BOOL CredDeleteW(
    #   LPCWSTR TargetName,
    #   DWORD   Type,
    #   DWORD   Flags
    # );
    extern 'BOOL CredDeleteW(LPCWSTR, DWORD, DWORD)'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/nf-wincred-credfree
    #
    # void CredFree(
    #   PVOID Buffer
    # );
    extern 'void CredFree(PVOID)'

    extern 'DWORD GetLastError(void)'

    # https://docs.microsoft.com/en-us/windows/desktop/api/wincred/ns-wincred-credentialw
    CRED_TYPE_GENERIC = 0x1
    CRED_PERSIST_LOCAL_MACHINE = 0x2
    FLAGS_NONE = 0x0
  end
end
