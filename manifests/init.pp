class conjur (
  $appliance_url = $conjur::params::appliance_url,
  $authn_login = $conjur::params::authn_login,
  $authn_api_key = $conjur::params::authn_api_key,
  $ssl_certificate = $conjur::params::ssl_certificate,
  $authn_token = $conjur::params::authn_token,
  $host_factory_token = $conjur::params::host_factory_token,
) inherits conjur::params {
  if $authn_token {
    $token = $authn_token
  } else {
      if $authn_api_key {
      # otherwise, if we know the API key, use it
      $api_key = $authn_api_key
    } elsif $host_factory_token {
      $authn_login_parts = split($authn_login, '/')
      if $authn_login_parts[0] != 'host' {
        fail('can only create hosts with host factory')
      }
      $host_details = conjur_manufacture_host(
        $appliance_url, $authn_login_parts[1], $host_factory_token
      )
      $api_key = $host_details[api_key]
    }
    $token = conjur_token($appliance_url, $authn_login, $api_key)
  }
}
