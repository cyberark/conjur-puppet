# Puppet troubleshooting

This document can help you quickly identify and fix most common errors.

## Quick Guide

What kind of error are you seeing?
- [`Unknown function 'conjur::secret'`](#module-not-installed)
- [`(LoadError) no such file to load -- conjur/puppet_module/config`](#deferred-not-used-correctly)
- [`Conjur configuration not found on system`](#identity-not-set)
- [`Error while evaluating a Method call ... expects a Sensitive value, got Deferred`](#misuse-of-deferred-variables)
- [`Failed to open TCP connection to ... (getaddrinfo: No such host is known.)`](#incorrect-conjur-endpoint)
- [`Conjur server error: Unauthorized`](#incorrect-conjur-credentials)
- [`Could not find any pre-populated Conjur credentials in WinCred storage`](#wincred-credentials-not-correctly-set)
- [`Conjur server error: Not Found`](#variable-not-found)
- [`Conjur server error: SSL_connect returned=1 errno=0 state=error: certificate verify failed`](#incorrect-ssl-certificate)
- [`Cert file '/path/to/cert.pem' cannot be found!`](#certificate-path-cannot-be-used)
- [`Value of 'authn_api_key' must be wrapped in 'Sensitive()'!`](#authn_api_key-not-wrapped-in-sensitive)


## All Issues

### Module not installed

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Unknown function 'conjur::secret'
  ```

#### Known Causes
This is usually due to the `cyberark/conjur` module not being installed on the
Puppet server providing the catalog to the agent.

#### Resolution
Install the `cyberark/conjur` module using [our instructions](README.md#installation)
on Puppet master(s) as well as all compilation masters that will be used by the agent.

### `Deferred` not used correctly

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Could not retrieve catalog from remote server: Error 500 on SERVER: Internal Server Error: org.jruby.exceptions.LoadError: (LoadError) no such file to load -- conjur/puppet_module/config
  ```

#### Known Causes
This is usually due to the `conjur::secret` function not being correctly wrapped
in a `Deferred` function or the parameters to the `Deferred` wrapper not being
correctly passed in as an array.

#### Resolution
Follow [our instructions on usage exactly](README.md#conjur-module-basics)
and make note of our required use of
[`Deferred` functions](README.md#deferred-functions). 

In general, our secret retrieval should be invoked in this exact manner:
```puppet
Deferred(conjur::secret, ['var/name'])
```

### Identity not set

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Conjur configuration not found on system
  ```

#### Known Causes
This is usually due to the identity not specified neither in the catalog nor
the agent itself.

#### Resolution
Ensure that either the server or the agent contain valid identity information.


### Misuse of `Deferred` variables

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Server Error: Evaluation Error: Error while evaluating a Method call, 'unwrap' parameter 'arg' expects a Sensitive value, got Deferred (file: inlined-epp-text, line: 1, column: 26) on node conjurnode.cyberark.com
  ```

#### Known Causes
This problem is usually due to use of a `Deferred` function result in a non-deferred
(e.g. templated) context.

#### Resolution
When using results from this module, you must take care that any operations
that are handled at manifest compilation time (e.g. templating) is also done
via `Deferred` functions. See [our exmaple usage](README.md#example-usage) for
information on how to do this correctly.


### Incorrect Conjur endpoint

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Failed to open TCP connection to badserver.com (getaddrinfo: No such host is known.)
  ```

#### Known Causes
This problem occurs when the `appliance_url` for Conjur / DAP is either
incorrect or unreachable from the agent.

#### Resolution
Verify that the agent has the correct `appliance_url` set and that it is
reachable.


### Incorrect Conjur credentials

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Conjur server error: Unauthorized
  ```

#### Known Causes
This is usually due to credential values being incorrect for the
target Conjur / DAP server.

#### Resolution
Verify that `authn_login_id`, `authn_api_key`, and `account` are
correct for the server that you are trying to connect to.


### WinCred credentials not correctly set

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Warning: Could not find any pre-populated Conjur credentials in WinCred storage for https://conjur.cyberark.com
  ...
  Error: Failed to apply catalog: Conjur server error: POST data to https://conjur.cyberark.com/authn/myaccount//authenticate must not be empty!
  ```

#### Known Causes
This issue is caused by
[Windows Credentials](README.md#using-windows-registry--windows-credential-manager-windows-agents-only)
not having the matching crednetial for the server endpoint configured in the registry.

#### Resolution
Ensure that you have the correct credentials set in `Windows Credentials` for the
`appliance_url` configured in `Windows Registry`.


### Variable not found

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Debug: Fetching Conjur secret 'inventoryy/db-password'...
  ...
  Error: Failed to apply catalog: Conjur server error: Not Found
  ```

#### Known Causes
The variable requested cannot be found, is not set, or you do not have permissions
to access it.

#### Resolution
Ensure that the variable at the reuested ID exists, has a value, and that the
user configured has the permissions to retrieve it.


### Incorrect SSL certificate

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Conjur server error: SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get local issuer certificate)
  ```

#### Known Causes
The provided Conjur SSL signing certificate is either incorrect, invalid, or malformed.

#### Resolution
Ensure that `ssl_certificate` or `cert_file` correctly specifies the certificate
that can be used to validate the Conjur / DAP SSL certificate. Also ensure that
none of the certificates in the chain are expired as seen by the agent machine.


### Certificate path cannot be used

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Cert file '/path/to/conjur_ca.crt' cannot be found!
  ```

#### Known Causes
This issue is caused by the module being unable to parse the provided `cert_file`
parameter target.

#### Resolution
Ensure that the path specified in `cert_file` parameter is valid and that it is
readable by the process that is running the puppet agent.


### `authn_api_key` not wrapped in `Sensitive`

#### Symptoms
- You see an error in your Puppet logs that looks something like:
  ```
  Error: Failed to apply catalog: Value of 'authn_api_key' must be wrapped in 'Sensitive()'!
  ```

#### Known Causes
Parameter `authn_api_key` was not wrapped in `Sensitive()` class.

#### Resolution

Wrap the `authn_api_key` in `Sensitive()`:
```puppet
$db_password = Deferred(conjur::secret, ['inventory/db-password', {
  ...
  authn_api_key => Sensitive('actual_api_key_value'),
  ...
}])
```

If using Hiera, add this section to your variables used:
```yaml
lookup_options:
  '^conjur::authn_api_key':
    convert_to: 'Sensitive'
```
