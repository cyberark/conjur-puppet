#!/bin/bash -e

readonly compose_file='docker-compose.test.yml'
export COMPOSE_PROJECT_NAME="conjur-puppet_$(openssl rand -hex 3)"

checks=( syntax
         lint
         metadata_lint
         check:symlinks
         check:git_ignore
         check:dot_underscore
         check:test_file
         rubocop )

echo "Building the test image..."
docker-compose -f "$compose_file" build --pull

echo "Sanity checking the plugin..."

for check_type in ${checks[@]}; do
  echo "- Checking [$check_type]"
  docker-compose -f "$compose_file" run --rm test-runner \
    bundle exec rake "$check_type"

  echo "- Checking [$check_type]: OK"
done

echo "Running specs..."
docker-compose -f "$compose_file" run --rm test-runner \
  bundle exec rake parallel_spec
echo "Tests complete!"
