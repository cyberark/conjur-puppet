module "conjur_master" {
  source = "github.com/conjurdemos/conjur-intro//terraform_modules/conjur/ee-single-node?ref=puppet-windows"

  vpc_id = "${data.aws_vpc.selected.id}"
  resource_prefix = "${var.resource_prefix}"
  ssh_key_name = "${aws_key_pair.generated_key.key_name}"
  ssh_key_pem = "${tls_private_key.ssh_access_key.private_key_pem}"
}

output "conjur_master_public" {
  value = "${module.conjur_master.public_dns}"
}

output "conjur_master_private" {
  value = "${module.conjur_master.private_dns}"
}

output "conjur_master_password" {
  sensitive = true
  value = "${module.conjur_master.admin_password}"
}
