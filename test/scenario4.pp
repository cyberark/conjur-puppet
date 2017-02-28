# Scenario 4: Fetch a secret given a host name and API key,
# with preconfigured Conjur endpoint

class { conjur:
  authn_login => $facts['authn_login'],
  authn_api_key => Sensitive($facts['authn_api_key']),
}

$secret = conjur::secret('inventory/db-password')

notify {"Writing this secret to file: ${secret.unwrap}":}

file { '/tmp/test.pem':
  content => conjur::secret('inventory/db-password'),
  ensure => file,
}
