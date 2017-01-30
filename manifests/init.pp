# Class: conjur
# ===========================
#
# Full description of class conjur here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'conjur':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Author Name <author@domain.com>
#
# Copyright
# ---------
#
# Copyright 2017 Your name here, unless otherwise noted.
#
class conjur (
  $appliance_url = $conjur::params::appliance_url,
  $authn_login = $conjur::params::authn_login,
  $authn_api_key = $conjur::params::authn_api_key,
  $ssl_certificate = $conjur::params::ssl_certificate,
  $authn_token = $conjur::params::authn_token,
) inherits conjur::params {
  if $authn_token {
    $token = $authn_token
  } elsif $facts['conjur_token'] {
    # if node provided its own token, use it
    $token = $facts['conjur_token']
  } elsif $authn_api_key {
    # otherwise, if we know the API key, use it
    $token = conjur_token($appliance_url, $authn_login, $authn_api_key)
  }
}
