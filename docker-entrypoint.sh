#!/usr/bin/env bash

set -e

# This resolves the issue of a volume mount to `/conjur` overriding the `Gemfile.lock`
# from `docker build`.
#
# `/build-Gemfile.lock` is the `Gemfile.lock` created when bundle is run at build time.
# Copying this file into the working directory, `/conjur`, at runtime prevents issues
# associated with it being overwritten by a volume mount.
cp "/build-Gemfile.lock" "/conjur/Gemfile.lock"

exec "$@"
