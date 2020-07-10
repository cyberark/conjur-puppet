File { backup => false }

node default {
  if ($facts['windows_puppet_agent']) {
    $pem_file  = 'c:/tmp/test.pem'
  } else {
    $pem_file  = '/tmp/test.pem'
  }

  notify { "Including conjur module...": }
  include conjur

  notify { "Grabbing 'inventory/db-password' secret...": }
  $secret = conjur::secret('inventory/db-password')

  # WARNING: You should not print secrets like this to console in
  #          non-development environments!
  notify { "Writing secret '${secret.unwrap}' to $pem_file...": }
  file { $pem_file:
    ensure  => file,
    content => conjur::secret('inventory/db-password'),
  }

  notify { "Done!": }
}
