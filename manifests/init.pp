class conjur (
  String $appliance_url = $conjur::params::appliance_url,
  Optional[String] $authn_login = $conjur::params::authn_login,
  Optional[String] $ssl_certificate = $conjur::params::ssl_certificate,

  # NOTE these Anys are for compatibility with Puppet < 4.6, so that
  # Sensitive can be used if supported and Strings if not.
  Optional[Any] $authn_api_key = $conjur::params::authn_api_key,
  Optional[Any] $authn_token = $conjur::params::authn_token,
  Optional[Any] $host_factory_token = $conjur::params::host_factory_token,
) inherits conjur::params {
  $client = conjur::client($appliance_url, $ssl_certificate)

  file { '/etc/conjur.conf':
    replace => false,
    content => "appliance_url: $appliance_url\ncert_file: /etc/conjur.pem"
  }

  file { '/etc/conjur.pem':
    replace => false,
    content => $ssl_certificate
  }

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
      $host_details = $client.conjur::manufacture_host(
        $authn_login_parts[1], $host_factory_token
      )
      $api_key = $host_details[api_key]
    }

    file { '/etc/conjur.identity':
      replace => false,
      mode => '0400',
      backup => false,
      show_diff => false,
      content => conjur::netrc($client[uri], $authn_login, $api_key)
    }

    $token = $client.conjur::token($authn_login, $api_key)
  }
}
