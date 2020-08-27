File { backup => false }

node default {
  if $facts['os']['family'] == 'Windows' {
    $cred_file_prefix = 'c:/tmp'
  } else {
    $cred_file_prefix = '/tmp'
  }

  $output_file1 = "${cred_file_prefix}/creds1.txt"
  $output_file2 = "${cred_file_prefix}/creds2.txt"

  # If using server-supplied identity for the agent's Conjur / DAP connection,
  # you would use the optional parameters to the `conjur::secret` function as
  # shown below.
  #
  # $secret = Sensitive(Deferred(conjur::secret, ['inventory/db-password', {
  #   appliance_url => lookup('conjur::appliance_url'),
  #   account => lookup('conjur::account'),
  #   authn_login => lookup('conjur::authn_login'),
  #   authn_api_key => lookup('conjur::authn_api_key'),
  #   ssl_certificate => lookup('conjur::ssl_certificate')
  # }]))

  notify { "Writing regular secret to ${output_file1}...": }
  file { $output_file1:
    ensure => file,
    content => Sensitive(Deferred(conjur::secret, ['inventory/db-password'])),
  }

  notify { "Writing funky secret to ${output_file2}...": }
  file { $output_file2:
    ensure => file,
    content => Sensitive(Deferred(conjur::secret, [
          'inventory/funky/special @#$%^&*(){}[].,+/variable'
    ])),
  }

  exec { "cat ${output_file1}":
    path      => '/usr/bin:/usr/sbin:/bin',
    provider  => shell,
    logoutput => true,
  }

  exec { "cat ${output_file2}":
    path      => '/usr/bin:/usr/sbin:/bin',
    provider  => shell,
    logoutput => true,
  }

  notify { 'Done!': }
}
