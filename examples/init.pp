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
  appliance_url => "https://localhost:8443/api",
  authn_login => "host/pptest",
  authn_api_key => "pj6qs7gbb6aek4r57a2evnz4v1jh3tj62g5vf4a2rmhyj52b5q9rb"
}

file { '/tmp/test.pem':
  content => conjur_secret('test_secret'),
  ensure => file,
  show_diff => false  # don't log file content!
}
