# Configure the AWS Provider
provider "aws" {
}

#############################################
# Inputs
#############################################

variable "resource_prefix" {
  type = "string"
  default = ""
}

variable "availability_zone" {
  default = "us-east-1a"
}

variable "vpc_id" {
  default = "vpc-3ee89c46"
}

#############################################
# State Information from AWS
#############################################

data "aws_vpc" "selected" {
  #default = true
  id = "${var.vpc_id}"
}

data "aws_subnet" "subnet" {
  vpc_id            = "${data.aws_vpc.selected.id}"
  availability_zone = "${var.availability_zone}"
}
