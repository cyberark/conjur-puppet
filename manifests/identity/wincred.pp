# Responsible for storing Conjur indentity information in the
# Windows Credential Manager.
class conjur::identity::wincred inherits conjur {
  if $conjur::api_key {

    $client_url = URI($conjur::client[uri]) + 'authn'

    wincred_credential { "${client_url}":
      ensure   => present,
      username => $conjur::authn_login,
      value    => $conjur::api_key
    }
  }
}
