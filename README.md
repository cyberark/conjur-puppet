# Connecting Puppet and Conjur Using a Custom Fact

The Puppet agent provides a Conjur access token to the Puppet master in a custom fact called `conjur_token`.

## Running the Server

Run `./start.sh`, which:

* Builds all the necessary containers
* Starts the `conjur` server
* Loads policies into Conjur
* Creates a new Host Factory token for the `prod/inventory` layer and saves it to a file
* Launches all the Puppet server containers.

## Running the Client (Node)

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
Info: Creating a new SSL key for d0876dbdf4a0
Info: Caching certificate for ca
Info: csr_attributes file loading from /etc/puppetlabs/puppet/csr_attributes.yaml
Info: Creating a new SSL certificate request for d0876dbdf4a0
Info: Certificate Request fingerprint (SHA256): 2B:23:DA:42:80:83:CC:B1:9D:FB:FF:C7:8A:7C:24:57:35:5C:D6:87:48:48:9A:5A:E1:7C:2C:0E:1D:15:97:5D
Info: Caching certificate for d0876dbdf4a0
Info: Caching certificate_revocation_list for ca
Info: Caching certificate for ca
Info: Using configured environment 'production'
Info: Retrieving pluginfacts
Info: Retrieving plugin
Info: Caching catalog for d0876dbdf4a0
Info: Applying configuration version '1481059553'
Notice: /Stage[main]/Main/Node[default]/File[/tmp/puppet-in-docker]/ensure: defined content as '{md5}938727d2f2612b38d783932417edf030'
Info: Creating state file /opt/puppetlabs/puppet/cache/state/state.yaml
Notice: Applied catalog in 0.09 seconds
Changes:
            Total: 1
Events:
          Success: 1
            Total: 1
Resources:
          Changed: 1
      Out of sync: 1
            Total: 8
Time:
       Filebucket: 0.00
         Schedule: 0.00
             File: 0.04
   Config retrieval: 1.02
            Total: 1.06
         Last run: 1481059553
Version:
           Config: 1481059553
           Puppet: 4.8.0
```


## Viewing the Node with the Conjur UI

Open the Conjur UI on port 9443. You'll be able to find the Puppet resources by searching for "puppet".

## Viewing the Node with Puppet Explorer

Note the port number for the puppetexplorer container, in my case `32828`. If
you're running docker locally you should be able to access the dashboard
on `0.0.0.0:32824` (your port will likely vary). If you're running
`docker-machine` then you can run `docker-machine ip` to determine the
correct IP address. 

## Exploring PuppetDB data

PuppetDB also exposes a dashboard, showing various operational metrics,
as well as [an API](https://docs.puppet.com/puppetdb/latest/api/) for
accessing all the collected resource data. You can find the port for the
dashboard using `docker ps` described above. The `docker port` command can
also be useful.

```
$ docker port compose_puppetdb_1
8080/tcp -> 0.0.0.0:32826
8081/tcp -> 0.0.0.0:32825
```

With that port in hand, and the ip address of the machine running docker,
you can query the PuppetDB API.

```
$ curl -s -X GET http://192.168.99.100:32826/pdb/query/v4 --data-urlencode 'query=nodes {}' | jq
{
    "deactivated": null,
    "latest_report_hash": "f8332ac22e0abf6a51571fae6b57b2a881f207fe",
    "facts_environment": "production",
    "cached_catalog_status": "not_used",
    "report_environment": "production",
    "catalog_environment": "production",
    "facts_timestamp": "2016-05-27T12:47:04.495Z",
    "latest_report_noop": false,
    "expired": null,
    "report_timestamp": "2016-05-27T12:47:04.144Z",
    "certname": "a9efc038b3ca",
    "catalog_timestamp": "2016-05-27T12:47:05.038Z",
    "latest_report_status": "changed"
  },
  {
    "deactivated": null,
    "latest_report_hash": "d273124e1e74708272228ac4465f6f1923100db7",
    "facts_environment": "production",
    "cached_catalog_status": "not_used",
    "report_environment": "production",
    "catalog_environment": "production",
    "facts_timestamp": "2016-05-27T12:47:37.543Z",
    "latest_report_noop": false,
    "expired": null,
    "report_timestamp": "2016-05-27T12:47:36.959Z",
    "certname": "5a4cbf61e790",
    "catalog_timestamp": "2016-05-27T12:47:38.050Z",
    "latest_report_status": "changed"
  }
]
```

Here I'm issuing a [PQL](https://docs.puppet.com/puppetdb/latest/api/query/v4/pql.html)
query for all nodes. I'm parsing it through [jq](https://stedolan.github.io/jq/) for
nicer formatting.

PuppetDB stores a great deal of information, and PQL and the API provides a
powerful way of accessing it. The Puppet-in-Docker setup makes for a great
experimental test bed for building atop that capability.

## Troubleshooting

In case you see errors like the this on the puppet container:

```
ERROR [puppetserver] Puppet Failed to execute '/pdb/cmd/v1?checksum=eeb40197db6a4ac3d8bce09778388cf7a812a621&version=5&certname=puppetdb.local&command=replace_facts' on at least 1 of the following 'server_urls': https://puppetdb:8081
ERROR [c.p.h.c.i.PersistentSyncHttpClient] Error executing http request
 java.net.ConnectException: Connection refused
```

Try to uncomment the following lines in the definition of the puppet service in the `docker-compose.yaml` file:

```
environment:
  - PUPPETDB_SERVER_URLS=https://puppetdb.local:8081
links:
  - puppetdb:puppetdb.local
```
