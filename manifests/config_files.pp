class conjur::config_files inherits conjur {
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
      $conjur::cert_file
    )
  }


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
