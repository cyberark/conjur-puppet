#!/usr/bin/env bash

set -e

# This resolves the issue with a volume mount to `/conjur` overriding the `Gemfile.lock`
# from `docker build`.
cp "/tmp/Gemfile.lock" "Gemfile.lock"

exec "$@"
