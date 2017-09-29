# Scenario 2: Fetch a secret given a host name and Host Factory token

class { 'conjur':
  account            => 'cucumber',
  appliance_url      => $facts['appliance_url'],
  authn_login        => $facts['authn_login'],
  host_factory_token => Sensitive($facts['host_factory_token']),
  ssl_certificate    => $facts['ssl_certificate'],
  version            => Integer($facts['conjur_version']),
}

$secret = conjur::secret('inventory/db-password')

notify {"Writing this secret to file: ${secret.unwrap}":}

file { '/tmp/test.pem':
  ensure  => file,
  content => conjur::secret('inventory/db-password'),
}
