File { backup => false }

node default {
  if $facts['os']['family'] == 'Windows' {
    $pem_file = 'c:/tmp/test.pem'
  } else {
    $pem_file = '/tmp/test.pem'
  }

  notify { 'Including conjur module...': }

  notify { "Grabbing 'inventory/db-password' secret...": }
  $secret = Sensitive(Deferred(conjur::secret, ['inventory/db-password']))

  # If using server-supplied identity for the agent's Conjur / DAP connection,
  # you would use the optional parameters to the `conjur::secret` function as
  # shown below.
  #
  # $secret = Sensitive(Deferred(conjur::secret, ['inventory/db-password',
  #   lookup('conjur::appliance_url'),
  #   lookup('conjur::account'),
  #   lookup('conjur::authn_login'),
  #   lookup('conjur::authn_api_key'),
  #   lookup('conjur::ssl_certificate')
  # ]))

  notify { "Writing secret to ${pem_file}...": }
  file { $pem_file: ensure => file, content => $secret }

  exec { 'cat /tmp/test.pem':
    path      => '/usr/bin:/usr/sbin:/bin',
    provider  => shell,
    logoutput => true,
  }

  notify { 'Done!': }
}
