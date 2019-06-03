# Responsible for storing Conjur connection information in a
# POSIX-based file system.
class conjur::config::files inherits conjur {
  if $conjur::ssl_certificate {
    $cert_file = '/etc/conjur.pem'
    file { $cert_file:
      replace => false,
      content => $conjur::ssl_certificate
    }
  } else {
    $cert_file = undef
  }

  file { '/etc/conjur.conf':
    replace => false,
    content => conjur::config_yml(
      $conjur::appliance_url,
      $conjur::version,
      $conjur::authn_account,
      $cert_file
    )
  }
}
