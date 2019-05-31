# Responsible for storing Conjur indentity information in the
# Windows Credential Manager.
class conjur::identity::wincred inherits conjur {
  if $conjur::api_key {
    credential { "${conjur::client[uri]}":
      ensure   => present,
      username => $conjur::authn_login,
      value    => $conjur::api_key
    }
  }
}
