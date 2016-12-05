variable "env_name"     { }
variable "domain"       { }
variable "region"       { }
variable "azs"          { type = "list" }
variable "vpc_cidr"     { }
variable "public_cidrs" { type = "list" }

variable "public_key"   { default = "~/.ssh/id_rsa.pub" }

provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source = "../modules/vpc"

  env_name = "${var.env_name}"
  azs = "${var.azs}"
  vpc_cidr = "${var.vpc_cidr}"
  public_cidrs = "${var.public_cidrs}"
}

resource "aws_key_pair" "deploy" {
  key_name_prefix = "${var.env_name}"
  public_key = "${file(var.public_key)}"
}

resource "aws_ecs_cluster" "default" {
  name = "${var.env_name}"
}

module "bastion" {
  source = "../modules/instance"

  domain = "${var.domain}"
  role = "bastion"
  vpc_id = "${module.vpc.id}"
  subnet_ids = "${module.vpc.public_subnet_ids}"
  key_name = "${aws_key_pair.deploy.key_name}"

  ingress_ports = ["tcp/22"]
}

module "ecs" {
  source = "../modules/instance"

  domain = "${var.domain}"
  role = "ecs"
  vpc_id = "${module.vpc.id}"
  subnet_ids = "${module.vpc.public_subnet_ids}"
  key_name = "${aws_key_pair.deploy.key_name}"

  desired_capacity = 3
  iam_profile = "ecs"
  user_data_file = "ecs.yml"
  user_data_vars {
    ecs_cluster = "${aws_ecs_cluster.default.name}"
  }
}
