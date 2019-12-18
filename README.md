# conjur

[![Version](https://img.shields.io/puppetforge/v/cyberark/conjur.svg)](https://forge.puppet.com/cyberark/conjur)

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
  ensure    => file,
  content   => conjur::secret("domains/%{hiera('domain')}/ssl-cert"),
  show_diff => false # only required for Puppet < 4.6
  # diff will automatically get redacted in 4.6 if content is Sensitive
}
```

#### Sensitive data type

Note `conjur::secret` returns values wrapped in a `Sensitive` data type. In
some contexts, such as string interpolation, it might cause surprising results
(interpolating to `Sensitive [value redacted]`). This is intentional, as it
makes it more difficult to accidentally mishandle secrets.

To use a secret as a string, you need to explicitly request it using the
`unwrap` function; the result of the processing should be again wrapped in
a `Sensitive` value.

In particular, you should not pass unwrapped secrets as resource parameters
if you can avoid it. Many resource types support `Sensitive` data type and
handle it correctly. If a resource you're using does not, file a bug.

```puppet
$dbpass = conjur::secret('production/postgres/password')

# Use Sensitive data type to handle anything sensitive
$db_yaml = Sensitive("password: ${dbpass.unwrap}")

file { '/etc/someservice/db.yaml':
  ensure  => file,
  content => $db_yaml, # this correctly handles both Sensitive and String
  mode    => '0600' # remember to limit reading
}
```

## Usage

This module provides the `conjur::secret` function, described above, and the `conjur` class, which can be configured to establish Conjur host identity on the node running Puppet.

### Pre-established host identity

For best security properties, use [conjurize](https://www.conjur.org/get-started/machine-identity.html) or a similar method to establish host identity before running Puppet to configure. This way Puppet master only ever handles a temporary access token instead of real, permanent Conjur credentials of the hosts it manages.

If a host is so pre-configured, the settings and credentials are automatically obtained and used. In this case, all that is needed to use `conjur::secret` is a simple

```puppet
include conjur
```

#### <a name="windows"></a>Pre-establish Host Identity on Windows Hosts

Connection settings for Conjur are stored in the Windows Registry under the key `HKLM\Software\CyberArk\Conjur`.
The values available to set are:

| Value Name | Value Type | Description |
|-|-|-|
| Account | REG_SZ | Conjur account specified during Conjur setup. |
| ApplianceUrl | REG_SZ | Conjur API endpoint. |
| SslCertificate | REG_SZ | public Conjur SSL cert. |
| Version | REG_DWORD | Conjur API version. Defaults to `5`. |

These may be set using Powershell:

```powershell
> reg ADD HKLM\Software\CyberArk\Conjur /v ApplianceUrl /t REG_SZ /d https://master.conjur.net
The operation completed successfully.
  > reg ADD HKLM\Software\CyberArk\Conjur /v Version /t REG_DWORD /d 5
The operation completed successfully.
  > reg ADD HKLM\Software\CyberArk\Conjur /v Account /t REG_SZ /d myorg
The operation completed successfully.
  > reg ADD HKLM\Software\CyberArk\Conjur /v SslCertificate /t REG_SZ /d "-----BEGIN CERTIFICATE-----..."
The operation completed successfully.
```

Credentials for Conjur are stored in the Windows Credential Manager. The credential `Target` is the Conjur authentication URL (e.g. `https://conjur.myorg.net/authn`). The username is the host ID, with a `host/` prefix (e.g. `host/my-host`). The credential password is the host's API key.

This may be set using Powershell:
 ```powershell
> cmdkey /generic:https://conjur.net/authn /user:hosts/my-host /pass
Enter the password for 'hosts/my-host' to connect to 'https://conjur.net/authn': # {Prompt for API Key}

CMDKEY: Credential added successfully.
```

### Conjur host identity with Host Factory

If pre-establishing host identity is unfeasible, we instead recommend bootstrapping Conjur host identity using a [Host Factory](https://developer.conjur.net/reference/services/host_factory) token. Nodes inherit the permissions of the layer for which the Host Factory token was generated.

Note when used in this manner, the host factory token will only be used on the initial Puppet run, to establish identity which is then stored on the host. Subsequent runs will use that for Conjur authentication on the node side (at the time of collecting facts) and only provide the Puppet master with a temporary token to fetch the secrets with.

To use a Host Factory token with this module, set variables `authn_login` and `host_factory_token`. Do not set the variable `authn_api_key` when using `host_factory_token`; it is not required. `authn_login` should have a `host/` prefix; the part after the slash will be used as the node’s name in Conjur.

```puppet
class { 'conjur':
  account            => 'mycompany',
  appliance_url      => 'https://conjur.mycompany.com/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('3zt94bb200p69nanj64v9sdn1e15rjqqt12kf68x1d6gb7z33vfskx'),
  ssl_certificate    => file('/etc/conjur.pem')
}
```

By default, all nodes using this Puppet module to bootstrap identity with host_factory_token will have the following annotation set:

```yaml
puppet: true
```

### Conjur host identity with API key

For one-off hosts or test environments it may be preferable to create a host in Conjur and then directly assign its Conjur identity in this module.

```puppet
class { 'conjur':
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('/conjur-ca.pem')
}
```

## Reference

### Classes

#### Public Classes

* [`conjur`](#conjur-class): Establishes a host identity on the node.

### Functions

#### Public Functions

* [`conjur::secret`](#conjursecret): Retrieve a secret using the host identity.

### Facts

#### Private facts

* [`conjur`](#conjur-fact): Reports current node configuration and identity.

### `conjur` class

This class establishes Conjur host identity on the node so that secrets can be fetched from Conjur. The identity and Conjur endpoint configuration can be pre-configured on a host using `/etc/conjur.conf` and `/etc/conjur.identity` (by the way of [`conjur` fact](#conjur-fact)) or provided as parameters. The identity can also be bootstrapped using a host factory token.

#### Note

Several parameters (ie. API keys) are of `Sensitive` data type.
To pass a normal string, you need to wrap it using `Sensitive("example")`.

#### Parameters

##### `account`
Conjur account authority name. Optional for v4, required for v5.

##### `appliance_url`
A Conjur endpoint (with trailing `/api/` for v4).

##### `authn_login`
User username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host. Must be `Sensitive` if supported.

##### `ssl_certificate`
Content of the X509 certificate of the root CA of Conjur, PEM formatted.
When using Puppet's `file` function, the path to the cert must be absolute.

##### `host_factory_token`
You can use a host factory token to obtain a host identity. Must be `Sensitive`.
Simply use this parameter to set it. The host record will be created in Conjur.

##### `authn_token`
Raw (unencoded) Conjur token. This is usually only useful for testing.
Must be `Sensitive`.

##### `version`
Conjur API version. Defaults to 5. Set to 4 if you're using Conjur Enterprise 4.x.

#### Examples

```puppet
# use a pre-existing Conjur configuration host identity
include conjur

# using an host factory token
class { 'conjur':
  appliance_url      => 'https://conjur.mycompany.com/',
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate    => file('conjur-ca.pem'),
  version            => 5
}

# same, but /etc/conjur.conf and certificate are already on a host
# (eg. baked into a base image)
class { 'conjur':
  authn_login        => 'host/redis001',
  host_factory_token => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3')
}

# using an API key
class { 'conjur':
  account         => 'mycompany',
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  ssl_certificate => file('conjur-ca.pem'),
  version         => 5
}
```

### `conjur::secret`

This function uses the node’s Conjur host identity to authenticate with Conjur and retrieve a secret that the node is authorized to fetch. The output of this function is a string that contains the value of the variable parameter. If the secret cannot be fetched an error is thrown.

The returned value is `Sensitive` data type.

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

```puppet
dbpass = conjur::secret('production/postgres/password')
```

### `conjur` fact

This internal, structured fact is used to inform the master of the current node Conjur configuration and identity.

Preestablishing configuration and identity is the recommended way of using this module, for example by pre-baking the configuration into a base image and bootstrapping the identity using an orchestration solution (see [Usage](#usage) section). If used this way, the Puppet master only has access to the 8-minute bearer token issued for the host and never handles long-term credentials.

- If the node is preconfigured with Conjur settings, they're reported in this fact and they're used as defaults by the `::conjur` class.
- If additionally the host has a Conjur identity pre-configured (eg. API key in `/etc/conjur.identity`), node uses that to authenticate to Conjur. It gets back the standard temporary Conjur token which is encrypted with the Puppet master public TLS key and reported in this fact. This ensures only the master (with the corresponding private key) can decrypt and use it.

## Limitations

See metadata.json for supported platforms

## Development

Open an issue or fork this project and open a Pull Request.

## Support

Please note, that this is a "Partner Supported" module, which means that  technical customer support for this module
is solely provided by Conjur.

Puppet does not provide support for any Partner Supported modules. For technical support please visit the Conjur channnel at https://discuss.cyberarkcommons.org/.
