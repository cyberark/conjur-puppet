# Scenario 1: Fetch a secret given a host name and API key

class { conjur:
  appliance_url => $facts['appliance_url'],
  authn_login => $facts['authn_login'],
  authn_api_key => Sensitive($facts['authn_api_key']),
  ssl_certificate => $facts['ssl_certificate']
}

$secret = conjur::secret('inventory/db-password')

notify {"Writing this secret to file: ${secret.unwrap}":}

file { '/tmp/test.pem':
  content => conjur::secret('inventory/db-password'),
  ensure => file,
}
