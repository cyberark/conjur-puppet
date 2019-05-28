class conjur (
  String $appliance_url = $conjur::params::appliance_url,
  Optional[String] $authn_login = $conjur::params::authn_login,
  Optional[String] $ssl_certificate = $conjur::params::ssl_certificate,

  Optional[String] $account = $conjur::params::account,
  Integer $version = $conjur::params::version,

  Optional[Sensitive] $authn_api_key = $conjur::params::authn_api_key,
  Optional[Sensitive] $authn_token = $conjur::params::authn_token,
  Optional[Sensitive] $host_factory_token = $conjur::params::host_factory_token,
) inherits conjur::params {
  $client = conjur::client($appliance_url, $version, $ssl_certificate)

  if $authn_token {
    $token = $authn_token
    $authn_account = $account
    $api_key = undef
  } else {
    if $authn_api_key {
      # otherwise, if we know the API key, use it
      $api_key = $authn_api_key
      $authn_account = $account
    } elsif $host_factory_token {
      $authn_login_parts = split($authn_login, '/')
      if $authn_login_parts[0] != 'host' {
        fail('can only create hosts with host factory')
      }
      $host_details = $client.conjur::manufacture_host(
        $authn_login_parts[1], $host_factory_token
      )
      $api_key = $host_details[api_key]
      $authn_account = split($host_details[id], ':')[0]
    }

    $token = $client.conjur::token($authn_login, $api_key, $authn_account)
  }

  require conjur::config::files
  require conjur::identity::files
}
