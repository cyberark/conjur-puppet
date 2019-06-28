# Contributing

For general contribution and community guidelines, please see the [community repo](https://github.com/cyberark/community).

# Running tests

See [jenkins.sh](jenkins.sh).

### Integration Tests

Running the integration tests in AWS requires that these environment variables are set:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

These are used to create the AWS resources for the integration tests. These may be provided
directly in the environment, for example:

```sh-session
$ export AWS_ACCESS_KEY_ID=...
$ export AWS_SECRET_ACCESS_KEY=...
$ export AWS_DEFAULT_REGION=...
$ ./integration-test.sh
```

Or provided using [Summon](https://cyberark.github.io/summon/). e.g.:

```sh-session
$ summon -f secrets_integration.yml ./integration-test.sh
```

# Publishing the module to Puppet Forge

To release a new version of the module to the Puppet Forge:

1. Update the `version` field in [metadata.json](metadata.json).
2. Update [CHANGELOG.md](CHANGELOG.md).
3. Commit and push these changes.
4. Create an annotated tag and push it (`git tag <VERSION> -m <VERSION> && git push --tags`)
5. Verify the Jenkins pipeline completes successfully.
6. View the updated module: https://forge.puppet.com/cyberark/conjur

You must be connected to conjurops v2 to fetch the secrets used to publish.

# Running services locally

## Running a Conjur server locally

Run a preconfigured Conjur instance with `docker-compose up -d`.
Username is 'admin', password is 'ADmin123!!!!'. The HTTPS endpoint is mapped to port `9443`.
Once the server is running, view the UI at [localhost:9443/ui](https://localhost:9443/ui).
You can ignore the cert warning; a self-signed cert is used.

## Running a Puppet master locally

Run a Puppet master with `./puppet-master.sh`. This script wraps running `docker-compose.puppet.yml`, where
all services needed to run the master are defined. The `code` directory in this project is mounted
onto the master at `/etc/puppetlabs/code/`. Open [localhost:8080](http://localhost:8080) to view the Puppet Dashboard.
You can stop and remove all services with `docker-compose -f docker-compose.puppet.yml down`.

## Running a Puppet node locally

Puppet [provides Docker images](https://github.com/puppetlabs/puppet-in-docker#description)
that make running ephemral Puppet agents pretty easy.

For example, once the Puppet master is up you can run this to converge an agent:

```sh-session
$ docker run --rm --net puppet_default puppet/puppet-agent-ubuntu
```

You will see Puppet converge on the node.

A couple notes:

1. docker-compose creates the `puppet_default` network by default. The agent needs to connect to this
   network to be able to see the Puppet master.
2. The default command for these agent images is `agent --verbose --one-time --no-daemonize --summarize`.
   The default entrypoint is `/opt/puppetlabs/bin/puppet `.
   This can easily be overridden for your purposes, e.g.

   ```sh-session
   $ docker run --rm --net puppet_default \
     puppet/puppet-agent-ubuntu apply --modulepath=$PWD examples/init.pp
   ```

   Note that if you want to run manifests directly then need to be mounted into the container.

## Contributing

1. [Fork the project](https://help.github.com/en/github/getting-started-with-github/fork-a-repo)
2. [Clone your fork](https://help.github.com/en/github/creating-cloning-and-archiving-repositories/cloning-a-repository)
3. Make local changes to your fork by editing files
3. [Commit your changes](https://help.github.com/en/github/managing-files-in-a-repository/adding-a-file-to-a-repository-using-the-command-line)
4. [Push your local changes to the remote server](https://help.github.com/en/github/using-git/pushing-commits-to-a-remote-repository)
5. [Create new Pull Request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork)

From here your pull request will be reviewed and once you've responded to all
feedback it will be merged into the project. Congratulations, you're a
contributor!
