# conjur

[![Version](https://img.shields.io/puppetforge/v/conjur/conjur.svg)](https://forge.puppet.com/conjur/conjur)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with conjur](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with conjur](#beginning-with-conjur)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)
7. [Support - "Puppet Supported" details and contact info](#support)

## Description

This is the official Puppet module for [Conjur](https://www.conjur.org), a robust identity and access management platform. This module simplifies the operations of establishing Conjur host identity and allows authorized Puppet nodes to fetch secrets from Conjur.

## Setup

### Setup Requirements

This module requires that you have a Conjur endpoint available to the Puppet nodes using this module.

### Beginning with conjur

This module provides a `conjur::secret` function that can be used to retrieve secrets from Conjur. Given a Conjur variable identifier, `conjur::secret` uses the node’s Conjur identity to resolve and return the variable’s value.

```puppet
$dbpass = conjur::secret('production/postgres/password')
```

Hiera attributes can also be used to inform which secret should be fetched, depending on the node running the Conjur module. For example, if `hiera('domain')` returns `app1.example.com` and a Conjur variable named `domains/app1.example.com/ssl-cert` exists, the SSL certificate can be retrieved and written to a file like so:

```puppet
file { '/etc/ssl/cert.pem':
  content   => conjur::secret("domains/%{hiera('domain')}/ssl-cert"),
  ensure    => file
  show_diff => false # only required for Puppet < 4.6
  # diff will automatically get redacted in 4.6 if content is Sensitive
}
```

#### Sensitive data type (Puppet >= 4.6)

Note in Puppet >= 4.6 `conjur::secret` returns values wrapped
in a `Sensitive` data type. In some contexts, such as string interpolation,
it might cause surprising results (interpolating to `Sensitive [value redacted]`).
This is intentional, as it makes it harder to accidentally mishandle secrets.

To use a secret as a string, you need to explicitly request it using the
`unwrap` function; the result of the processing should be again wrapped in
a `Sensitive` value.

In particular, you should not pass unwrapped secrets as resource parameters
if you can avoid it. Many resource types support `Sensitive` data type and
handle it correctly. If a resource you're using does not, file a bug.

```puppet
$dbpass = conjur::secret('production/postgres/password')

# In Puppet 4.6, use Sensitive data type to handle anything sensitive
$db_yaml = Sensitive("password: ${dbpass.unwrap}")

file { '/etc/someservice/db.yaml':
  content => $db_yaml, # this correctly handles both Sensitive and String
  ensure  => file,
  mode    => '0600', # remember to limit reading
}
```

## Usage

This module provides the `conjur::secret` function, described above, and the `conjur` class, which can be configured to establish Conjur host identity on the node running Puppet.

### Pre-established host identity

For best security properties, use [conjurize](https://developer.conjur.net/key_concepts/machine_identity.html) or a similar method to establish host identity before running Puppet to configure. This way Puppet master only ever handles a temporary access token instead of real, permanent Conjur credentials of the hosts it manages.

If a host is so pre-configured, the settings and credentials are automatically obtained and used. In this case, all that is needed to use `conjur::secret` is a simple

```puppet
include conjur
```

### Conjur host identity with Host Factory

If pre-establishing host identity is unfeasible, we instead recommend bootstrapping Conjur host identity using a [Host Factory](https://developer.conjur.net/reference/services/host_factory) token. Nodes inherit the permissions of the layer for which the Host Factory token was generated.

To use a Host Factory token with this module, set variables `authn_login` and `host_factory_token`. Do not set the variable `authn_api_key` when using `host_factory_token`; it is not required. `authn_login` should have a `host/` prefix; the part after the slash will be used as the node’s name in Conjur.

```puppet
class { conjur:
  account            => 'mycompany',
  appliance_url      => 'https://conjur.mycompany.com/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'),
  ssl_certificate    => file('/etc/conjur.pem')
  version            => 5,
}
```

By default, all nodes using this Puppet module to bootstrap identity with host_factory_token will have the following annotation set:

```yaml
puppet: true
```

### Conjur host identity with API key

For one-off hosts or test environments it may be preferable to create a host in Conjur and then directly assign its Conjur identity in this module.

```puppet
class { conjur:
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('/conjur-ca.pem')
  version         => 5,
}
```

### Conjur Enterprise Edition

If you're using this module to establish host identity with Conjur Enterprise
Edition version 4.x, you should use `version => 4`. (This is also the default
for backwards compatibility reasons.) Also note that the `appliance_url` will
need to include the `/api/` suffix.

For example:

```puppet
class { conjur:
  appliance_url      => 'https://conjur.mycompany.com/api/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'),
  ssl_certificate    => file('/etc/conjur.pem')
  version            => 4,
}
```

## Reference

### Classes

#### Public Classes

* `::conjur`

### Functions

#### Public Functions

* `conjur::secret`

### `::conjur`

This class establishes Conjur host identity on the node so that secrets can be fetched from Conjur. The identity and Conjur endpoint configuration can be pre-configured on a host using `/etc/conjur.conf` and `/etc/conjur.identity` or provided as parameters. The identity can also be bootstrapped using a host factory token.

#### Note

Several parameters (ie. API keys) are of `Sensitive` data type on Puppet >= 4.6.
To pass a normal string, you need to wrap it using `Sensitive("example")`.

#### Parameters

##### `account`
Conjur account authority name. Optional for v4, required for v5.

##### `appliance_url`
A Conjur endpoint (with trailing `/api` for v4).

##### `authn_login`
User username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host. Must be `Sensitive` if supported.

##### `ssl_certificate`
Content of the X509 certificate of the root CA of Conjur, PEM formatted.
When using Puppet's `file` function, the path to the cert must be absolute.

##### `host_factory_token`
You can use a host factory token to obtain a host identity. Must be `Sensitive` if supported.
Simply use this parameter to set it. The host record will be created in Conjur.

##### `authn_token`
Raw (unencoded) Conjur token. This is usually only useful for testing.
Must be `Sensitive` if supported.

##### `version`
Conjur API version. Should be set to 5 unless you're using Conjur Enterprise 4.x.

Defaults to 4 for backward compatibility reasons. (This will change in a future version.)

#### Examples

```puppet
# use a pre-existing Conjur configuration host identity
include conjur

# using an host factory token
class { conjur:
  appliance_url      => 'https://conjur.mycompany.com/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate    => file('conjur-ca.pem')
  version            => 5,
}

# same, but /etc/conjur.conf and certificate are already on a host
# (eg. baked into a base image)
class { conjur:
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
}

# using an API key
class { conjur:
  account         => 'mycompany',
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('conjur-ca.pem')
  version         => 5,
}
```

### `conjur::secret`

This function uses the node’s Conjur host identity to authenticate with Conjur and retrieve a secret that the node is authorized to fetch. The output of this function is a string that contains the value of the variable parameter. If the secret cannot be fetched an error is thrown.

The returned value is `Sensitive` data type if supported (see notes above).

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

```puppet
dbpass = conjur::secret('production/postgres/password')
```

## Limitations

See metadata.json for supported platforms

## Development

Open an issue or fork this project and open a Pull Request.

## Support

Please note, that this is a "Partner Supported" module, which means that  technical customer support for this module
is solely provided by Conjur.

Puppet does not provide support for any Partner Supported modules. Technical support for the Conjur module can be reached via these channels: 
 
Formal requests: https://conjur.zendesk.com
 
Informal requests: support@conjur.com 
