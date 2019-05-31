require 'fiddle/import'
require 'fiddle/types'

module WinCred
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
