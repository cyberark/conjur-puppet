# Responsible for storing Conjur identity information in a
# POSIX-based file system.
class conjur::identity::files inherits conjur {
  if $conjur::api_key {
    file { '/etc/conjur.identity':
      replace   => false,
      mode      => '0400',
      backup    => false,
      show_diff => false,
      content   => conjur::netrc($conjur::client[uri], $conjur::authn_login, $conjur::api_key)
    }
  }
}
