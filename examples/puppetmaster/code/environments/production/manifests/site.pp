File { backup => false }

node default {
#  $sslcert = @("EOT")
#-----BEGIN CERTIFICATE-----
#-----END CERTIFICATE-----
#  |-EOT

#  class { 'conjur':
#    appliance_url      => 'https://conjur-https:8443',
#    account            => 'cucumber',
#    authn_login        => 'host/whatthat',
#    authn_login        => 'host/node01',
#    authn_api_key => Sensitive('qbxb7q7v48jc1mf06rm31vkk7ghacz5y3wk9pk2dfnfjm2ejm5xp'),
#    host_factory_token => Sensitive('1ymypez3qtzdz527rqgw52p435ae20zk96n20pfspd1jsmyct27fj1wz'),
#    # ssl_certificate    => $sslcert
#    ssl_certificate => file('/foo.pem')
#  }

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
