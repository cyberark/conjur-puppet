File { backup => false }

node default {
  if $facts['os']['family'] == 'Windows' {
    # There's a double backslash at the end of $cred_file_prefix because:
    # When a backslash occurs at the very end of a single-quoted string, a double
    # backslash must be used instead of a single backslash. For example:
    # path => 'C:\Program Files(x86)\\'
    $cred_file_prefix = 'c:\tmp\\'
    $win_cmd_exe = 'C:\Windows\System32\cmd.exe'
  } else {
    $cred_file_prefix = '/tmp/'
  }

  $output_file1 = "${cred_file_prefix}creds1.txt"
  $output_file2 = "${cred_file_prefix}creds2.txt"

  # If using server-supplied identity for the agent's Conjur connection,
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
    ensure  => file,
    content => Sensitive(Deferred(conjur::secret, ['inventory/db-password'])),
  }

  notify { "Writing funky secret to ${output_file2}...": }
  file { $output_file2:
    ensure  => file,
    content => Sensitive(Deferred(conjur::secret, [
          'inventory/funky/special @#$%^&*(){}[].,+/variable',
    ])),
  }

  # Test invoking the `conjur::secret` function directly on the server instead of deferring to the agent
  $nondeferred_secret = conjur::secret('inventory/db-password').unwrap

  if $nondeferred_secret != 'supersecretpassword' {
    fail("Expected Conjur secret to be 'supersecretpassword', but got '${nondeferred_secret}'")
  }

  if $facts['os']['family'] == 'Windows' {
    exec { "Read secret from ${output_file1}...":
      command   => "${win_cmd_exe} /c type ${output_file1}",
      logoutput => true,
    }
  } else {
    exec { "cat ${output_file1}":
      path      => '/usr/bin:/usr/sbin:/bin',
      provider  => shell,
      logoutput => true,
    }
  }

  if $facts['os']['family'] == 'Windows' {
    exec { "Read secret from ${output_file2}...":
      command   => "${win_cmd_exe} /c type ${output_file2}",
      logoutput => true,
    }
  } else {
    exec { "cat ${output_file2}":
      path      => '/usr/bin:/usr/sbin:/bin',
      provider  => shell,
      logoutput => true,
    }
  }

  notify { 'Done!': }
}
