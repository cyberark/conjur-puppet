# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# https://docs.puppet.com/guides/tests_smoke.html
#

class { conjur:
  appliance_url => $facts['appliance_url'],
  authn_login => $facts['authn_login'],
  host_factory_token => $facts['host_factory_token']
}

$secret = conjur_secret('inventory/db-password')

notify {"Writing this secret to file: $secret":}

file { '/tmp/test.pem':
  content => conjur_secret('inventory/db-password'),
  ensure => file,
  show_diff => false  # don't log file content!
}
