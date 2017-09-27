class conjur::config_files inherits conjur {
  if $ssl_certificate {
    $cert_file = '/etc/conjur.pem'
    file { $cert_file:
      replace => false,
      content => $ssl_certificate
    }
  } else {
    $cert_file = undef
  }

  file { '/etc/conjur.conf':
    replace => false,
    content => conjur::config_yml($appliance_url, $version, $authn_account, $cert_file)
  }


  if $api_key {
    file { '/etc/conjur.identity':
      replace   => false,
      mode      => '0400',
      backup    => false,
      show_diff => false,
      content   => conjur::netrc($client[uri], $authn_login, $api_key)
    }
  }
}
