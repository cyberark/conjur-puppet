# Scenario 4: Fetch a secret given a host name and API key,
# with preconfigured Conjur identity

include conjur

$secret = conjur::secret('inventory/db-password')

notify {"Writing this secret to file: ${secret.unwrap}":}

file { '/tmp/test.pem':
  ensure  => file,
  content => conjur::secret('inventory/db-password'),
}
