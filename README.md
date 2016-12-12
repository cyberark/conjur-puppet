# Connecting Puppet and Conjur

This project demonstrates how to inject Conjur-managed secrets into Puppet code. 

## Key concepts

* **Conjur connection** Both the client node and the Puppet master are both configured to connect to Conjur via `conjur.conf` and `conjur.pem`. 
* **Conjur identity**
  * **node-side** The client node has a Conjur identity, typically obtained via host factory token.
  * **master-side** The Puppet master does *not* have a Conjur identity.
* **Custom facts** The client node submits custom facts obtained from Conjur:
  * `conjur_token` An encrypted Conjur access token. The token is encrypted using the public certificate of the Puppet master; then decrypted by the Puppet master for use. Note that the access token also has a built-in expiration of 8 minutes, after which it is no longer valid.
  * `conjur_layers` An array of all the Conjur layers to which the node belongs.
* **Custom functions**
  * `conjur_secret` Looks up the value of a secret in Conjur. In this way it can be assigned to a Puppet variable and used like any variable.
* **Hiera** In this example, the `conjur_layers` fact is used in Hiera to assign Puppet class(es) to the node.

## Demo

This example shows how an `inventory` service can obtain a database password to the `inventory-db`. The `inventory` service is modeled as a Puppet-managed node. This node applies an `inventory` class, which fetches the secret from Conjur using the `conjur_token` fact and prints it to the console on the node-side.

In a more realistic example, the password would be merged into a file using a Puppet template.

### Running the Server

Run `./start.sh`, which:

* Builds all the necessary containers.
* Starts the `conjur` server.
* Loads policies into Conjur.
* Populates the `prod/inventory-db/password` variable.
* Creates a new Host Factory token for the `prod/inventory` layer and saves it to a file.
* Launches all the Puppet server containers..

### Running the Client (Node)

The `node` container uses the Host Factory token to acquire an identity. It then saves this identity information, and runs the Puppet agent. Facter authenticates with Conjur and passes the access token as a custom fact called
`conjur_token`:

```
$ docker-compose run --rm node
Starting compose_conjur_policies_1
+ host_id=puppet/d0876dbdf4a0
++ cat /etc/hostfactory_token.txt
+ token=13121xr1bffs5j9qxd242jc96rj3vbrzp412yc2t81aaqaxn2yhps30
+ conjur hostfactory hosts create 13121xr1bffs5j9qxd242jc96rj3vbrzp412yc2t81aaqaxn2yhps30 puppet/d0876dbdf4a0
++ cat /etc/host.json
++ jq -r .api_key
+ api_key=2cvenc2pyvb8h3xq2t2f80nyb3sgtfg528w0805nwa2sa1r2h1za
+ cat
+ chmod 0600 /root/.netrc
+ /opt/puppetlabs/bin/puppet agent --verbose --onetime --no-daemonize --summarize
Info: Using configured environment 'production'
Info: Retrieving pluginfacts
Info: Retrieving plugin
Info: Caching catalog for c020f6139c71
Info: Applying configuration version '1481572162'
Notice: Installing DB password: e4eabb1e741469407f8b9868
Notice: /Stage[main]/Inventory/Notify[Installing DB password: e4eabb1e741469407f8b9868]/message: defined 'message' as 'Installing DB password: e4eabb1e741469407f8b9868'
Notice: Applied catalog in 0.17 seconds
Changes:
            Total: 1
Events:
          Success: 1
            Total: 1
Resources:
          Changed: 1
      Out of sync: 1
            Total: 9
Time:
       Filebucket: 0.00
         Schedule: 0.00
           Notify: 0.00
             File: 0.02
   Config retrieval: 14.49
            Total: 14.51
         Last run: 1481572174
Version:
           Config: 1481572162
           Puppet: 4.8.0
root@c020f6139c71:/#
```

## Viewing the Node with the Conjur UI

Open the Conjur UI on port 9443. You'll be able to find the Puppet resources by searching for "puppet".

## Viewing the Node with Puppet Explorer

Note the port number for the puppetexplorer container, in my case `32828`. If
you're running docker locally you should be able to access the dashboard
on `0.0.0.0:32824` (your port will likely vary). If you're running
`docker-machine` then you can run `docker-machine ip` to determine the
correct IP address. 
