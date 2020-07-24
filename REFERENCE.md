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

This class establishes Conjur host identity on the node so that secrets can be
fetched from Conjur. The identity and Conjur endpoint configuration can be
pre-configured on a host using `/etc/conjur.conf` and `/etc/conjur.identity` on Linux, or
Windows Registry and Window Credentials Manager on Windows, (by way of
[`conjur` fact](#conjur-fact)) or provided as parameters. The identity can also be
bootstrapped using the host factory token parameter.

When this class is instantiated in such a way that it has access to an API key (`authn_api_key`),
the identity is persisted on the agent using the same OS specific machine identity
artifacts as mentioned in the pre-configured case above. This happens when the host
factory parameter is used since a host's API key is retrieved as part of that flow. _Note
that when this persistence occurs the `cert_file` parameter is always converted to the
`ssl_certificate` equivalent for the artifact._

#### Note

Several parameters (ie. API keys) are of `Sensitive` data type.
To pass a normal string, you need to wrap it using `Sensitive("example")`.

#### Parameters

##### `account`
Conjur account authority name. Optional for v4, required for v5.

##### `appliance_url`
A Conjur endpoint (with trailing `/api/` for v4).

##### `authn_login`
User's username or host name (prefixed with `host/`).

##### `authn_api_key`
API key for a user or host. Must be `Sensitive` if supported.

##### `cert_file`
File path to X509 certificate of the root CA of Conjur, PEM formatted. This file is read
from the **Puppet server**. Takes precedence over `ssl_certificate`.

##### `ssl_certificate`
Content of the X509 certificate of the root CA of Conjur, PEM formatted.
When using Puppet's `file` function, the path to the cert must be absolute.
Overwritten by the contents read from `cert_file` when it is present.

##### `host_factory_token`
You can use a host factory token to obtain a host identity. Must be `Sensitive`.
Simply use this parameter to set it. The host record is created in Conjur.

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
  ssl_certificate    => file('/absolute/path/to/conjur-ca.pem'),
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
  ssl_certificate => file('/absolute/path/to/conjur-ca.pem'),
  version         => 5
}

# same, but 'cert_file' is used instead of 'ssl_certificate'
class { 'conjur':
  account         => 'mycompany',
  appliance_url   => 'https://conjur.mycompany.com/',
  authn_login     => 'host/redis001',
  authn_api_key   => Sensitive('f9yykd2r0dajz398rh32xz2fxp1tws1qq2baw4112n4am9x3ncqbk3'),
  cert_file       => '/absolute/path/to/conjur-ca.pem', # Read from the Puppet server
  version         => 5
}
```

### `conjur::secret`

This function uses the node’s Conjur host identity to authenticate with Conjur
and retrieve a secret that the node is authorized to fetch. The output of this
function is a string that contains the value of the variable parameter. If the
secret cannot be fetched an error is thrown.

The returned value is `Sensitive` data type.

#### Parameters

##### `variable`
The identifier of a Conjur variable to retrieve.

#### Example

```puppet
dbpass = conjur::secret('production/postgres/password')
```

### `conjur` fact

This internal, structured fact is used to inform the master of the current node
Conjur configuration and identity.

Pre-establishing configuration and identity is the recommended way of using this
module, for example by pre-baking the configuration into a base image and bootstrapping
the identity using an orchestration solution (see [Usage](#usage) section). If
used this way, the Puppet master only has access to the 8-minute bearer token
issued for the host and never handles long-term credentials.

- If the node is preconfigured with Conjur settings, they're reported in this
  fact and they're used as defaults by the `::conjur` class.
- If additionally the host has a Conjur identity pre-configured (ie. API key in
  `/etc/conjur.identity` on Linux or Windows Credentials Manager on Windows), the node
  uses that to authenticate to Conjur. It gets back the standard temporary Conjur token
  which is encrypted with the Puppet master's public TLS key and reported in this fact. This
  ensures only the master (with the corresponding private key) can decrypt and use it.
