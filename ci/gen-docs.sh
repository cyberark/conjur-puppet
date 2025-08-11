#!/bin/bash

set -euo pipefail

strings_cmd="gem install puppet-strings && puppet strings generate --format markdown --out REFERENCE.md"

docker run -t \
           -v "$(pwd):/conjur" \
           -w /conjur \
           --entrypoint /bin/bash \
           ruby:slim -ec "$strings_cmd"
