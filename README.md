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

This example shows how an `inventory` service can obtain a database password to the `inventory-db`. The `inventory` service is modeled as a Puppet-managed node. This node applies an `inventory` class, which fetches the secret from Conjur using the `conjur_token` fact and writes it to the file `/dev/shm/etc/inventory.conf`

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
Info: Caching catalog for e220b44c5a20
Info: Applying configuration version '1481575407'
Notice: /Stage[main]/Inventory/File[/dev/shm/etc]/ensure: created
Notice: /Stage[main]/Inventory/File[/dev/shm/etc/inventory.conf]/ensure: defined content as '{md5}b2c57da40a62afa1fbf1f54f0ccdcb7e'
Notice: /Stage[main]/Inventory/File[/etc/inventory.conf]/ensure: created
Notice: Applied catalog in 0.07 seconds
Changes:
            Total: 3
Events:
          Success: 3
            Total: 3
Resources:
            Total: 11
      Out of sync: 3
          Changed: 3
Time:
         Schedule: 0.00
             File: 0.01
   Config retrieval: 1.15
            Total: 1.16
         Last run: 1481575408
       Filebucket: 0.00
Version:
           Config: 1481575407
           Puppet: 4.8.0
root@e220b44c5a20:/# cat /etc/inventory.conf
db_password: 2effa8d2f9b76f7b1e1fd507
root@e220b44c5a20:/# ls -al /etc/inventory.conf
lrwxrwxrwx 1 root root 27 Dec 12 20:43 /etc/inventory.conf -> /dev/shm/etc/inventory.conf
```

## Viewing the Node with the Conjur UI

Open the Conjur UI on port 9443. You'll be able to find the Puppet resources by searching for "puppet".

## Viewing the Node with Puppet Explorer

Note the port number for the puppetexplorer container, in my case `32828`. If
you're running docker locally you should be able to access the dashboard
on `0.0.0.0:32824` (your port will likely vary). If you're running
`docker-machine` then you can run `docker-machine ip` to determine the
correct IP address. 
