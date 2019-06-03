# Responsible for storing Conjur indentity information in the
# Windows Credential Manager.
class conjur::identity::wincred inherits conjur {

  # The Conjur server host name is the target name in Windows
  # Credential Manager.
  $cred_target = "${URI($conjur::client[uri]).host}"

  if $conjur::api_key {
    credential { "${cred_target}":
      ensure   => present,
      username => $conjur::authn_login,
      value    => $conjur::api_key
    }
  }
}
