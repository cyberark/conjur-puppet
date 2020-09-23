#!/bin/bash -ex

# To ensure this script always executes relative to the repo root
cd "$(dirname "$0")/.."

docker run --rm \
  --volume "${PWD}/CHANGELOG.md:/CHANGELOG.md"  \
  cyberark/parse-a-changelog
