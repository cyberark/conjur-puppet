# examples

This directory holds executable examples that illustrate the different ways to use the Conjur Puppet module.

The module is flexible enough to accomodate several different workflows.
The manifests in this directory illustrate different scenarios.
[smoketest.sh](smoketest.sh) uses docker-compose to test these scenarios.

## Policy

[policy.yml](policy.yml) defines an example "inventory" application that is composed of:
- `layer:inventory`: Layer for inventory hosts
- `host-factory:inventory`: Host Factory attached to the layer
- `variable:db-password`: Stores a database password

The `inventory` layer is permitted to `execute` (fetch) the variable `db-password`.

Reference material:

- https://developer.conjur.net/policy
- https://developer.conjur.net/reference/policy

## Manifests

- [scenario1.pp](scenario1.pp) - Fetch a secret given a host name and API key.
- [scenario2.pp](scenario2.pp) - Fetch a secret given a host name and Host Factory token.
- [scenario2.5.pp](scenario2.5.pp) - Fetch a secret given a host name and Host Factory token, Puppet <=4.5.
- [scenario3.pp](scenario3.pp) - Fetch a secret with preconfigured Conjur identity.
