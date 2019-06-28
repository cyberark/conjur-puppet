#!/bin/bash -eu

readonly compose_file='docker-compose.test.yml'

COMPOSE_PROJECT_NAME="$(basename "$PWD")_$(openssl rand -hex 3)"
export COMPOSE_PROJECT_NAME

rm -rf ./compose_project_name
echo "${COMPOSE_PROJECT_NAME}" > ./compose_project_name

export TF_VAR_resource_prefix="${COMPOSE_PROJECT_NAME}_"
export TF_VAR_vpc_id="${AWS_VPC_ID}"

function finish {
  if [ -d "tmp/terraform" ]; then
  echo "Cleaning up terraform resources"
  docker-compose -f "$compose_file" run --rm integration-runner \
    bash <<SCRIPT
      pushd tmp/terraform
        terraform init
        terraform destroy -auto-approve || true
      popd

      # Clean up temp dir here, Jenkins may not be able to
      rm -rf tmp
SCRIPT
  fi
}
trap finish EXIT

echo "Terraform AWS resource prefix is: ${COMPOSE_PROJECT_NAME}"
docker-compose -f "$compose_file" build --pull

# Build Puppet module
docker-compose -f "$compose_file" run --rm package-builder \
  bundle exec rake package

# Run integration tests
docker-compose -f "$compose_file" run --rm integration-runner \
 bundle exec cucumber
