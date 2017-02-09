# Scenario 1: Fetch a secret given a host name and API key

class { conjur:
  appliance_url => $facts['appliance_url'],
  authn_login => $facts['authn_login'],
  authn_api_key => $facts['authn_api_key'],
  ssl_certificate => $facts['ssl_certificate']
}

$secret = conjur_secret('inventory/db-password')

notify {"Writing this secret to file: $secret":}

file { '/tmp/test.pem':
  content => conjur_secret('inventory/db-password'),
  ensure => file,
  show_diff => false  # don't log file content!
}
