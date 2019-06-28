#!/bin/bash -eu

if [ -d "tmp/terraform" ]; then

  readonly compose_file='docker-compose.test.yml'

  COMPOSE_PROJECT_NAME="$(<./compose_project_name)"
  export COMPOSE_PROJECT_NAME

  export TF_VAR_resource_prefix="${COMPOSE_PROJECT_NAME}_"
  export TF_VAR_vpc_id="${AWS_VPC_ID}"

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
