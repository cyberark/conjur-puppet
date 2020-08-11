#!/bin/bash

set -euo pipefail

strings_cmd="gem install puppet-strings && puppet strings generate --format markdown --out REFERENCE.md"

docker run -it \
           -v "$(pwd):/conjur" \
           -w /conjur \
           --entrypoint /bin/bash \
           puppet/puppetserver:latest -ec "$strings_cmd"
