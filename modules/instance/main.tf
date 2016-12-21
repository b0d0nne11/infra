variable "env"              { }
variable "role"             { }
variable "domain"           { }
variable "vpc_id"           { }
variable "subnet_ids"       { type = "list" }
variable "key_name"         { }

variable "desired_capacity" { default = 1             }
variable "image_name"       { default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*" }
variable "type"             { default = "t2.micro"    }
variable "iam_profile"      { default = ""            }
variable "user_data_file"   { default = "default.yml" }
variable "user_data_vars"   { default = {}            }
variable "ingress_ports"    { default = []            }
variable "chef_server"      { default = "api.chef.io" }
variable "chef_org"         { default = "acme"        }
variable "chef_validation_file" { default = "~/.chefdk/acme-validator.pem" }
variable "chef_bastion_host"    { default = ""                             }

data "aws_ami" "selected_image" {
  most_recent = true
  filter {
    name = "name"
    values = ["${var.image_name}"]
  }
}

data "aws_route53_zone" "selected_zone" {
  name = "#{var.domain}"
}

data "aws_security_group" "vpc_default_sg" {
  vpc_id = "${var.vpc_id}"
  name = "default"
}

resource "aws_security_group" "role_sg" {
  vpc_id = "${var.vpc_id}"
  name = "${var.role}"
}

resource "aws_security_group_rule" "role_sg_ingress_ports" {
  count = "${length(var.ingress_ports)}"
  security_group_id = "${aws_security_group.role_sg.id}"
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
  # ingress_ports should be in the form 'proto/port'
  protocol  = "${element(split("/", element(var.ingress_ports, count.index)), 0)}"
  from_port = "${element(split("/", element(var.ingress_ports, count.index)), 1)}"
  to_port   = "${element(split("/", element(var.ingress_ports, count.index)), 1)}"
}

data "template_file" "user_data" {
  count = "${var.desired_capacity}"
  template = "${file(format("%s/files/user_data/%s", path.module, var.user_data_file))}"
  vars = "${merge(var.user_data_vars, map(
    "hostname", "${var.role}-${format("n%02d", count.index + 1)}",
    "fqdn",     "${var.role}-${format("n%02d", count.index + 1)}.${var.domain}"
  ))}"
}

resource "aws_instance" "cluster" {
  count = "${var.desired_capacity}"
  ami = "${data.aws_ami.selected_image.id}"
  instance_type = "${var.type}"
  subnet_id = "${element(var.subnet_ids, count.index)}"
  vpc_security_group_ids = [
    "${data.aws_security_group.vpc_default_sg.id}",
    "${aws_security_group.role_sg.id}"
  ]
  iam_instance_profile = "${var.iam_profile}"
  user_data = "${element(data.template_file.user_data.*.rendered, count.index)}"
  key_name = "${var.key_name}"
  tags {
    Name = "${element(data.template_file.user_data.*.vars.fqdn, count.index)}"
  }
  provisioner "chef" {
    connection {
      type = "ssh"
      host = "${var.chef_bastion_host == "" ? self.public_ip : self.private_ip}"
      user = "ubuntu"
      agent = true
      bastion_host = "${var.chef_bastion_host}"
    }
    server_url = "https://${var.chef_server}/organizations/${var.chef_org}"
    environment = "${var.env}"
    run_list = ["role[base]", "role[${var.role}]"]
    node_name = "${element(data.template_file.user_data.*.vars.fqdn, count.index)}"
    user_name = "${var.chef_org}-validator"
    user_key = "${file(var.chef_validation_file)}"
  }
}

output "instance_ids" {
  value = ["${aws_instance.cluster.*.public_ip}"]
}

resource "aws_route53_record" "cluster_a_record" {
  count = "${var.desired_capacity}"
  zone_id = "${data.aws_route53_zone.selected_zone.zone_id}"
  name = "${element(data.template_file.user_data.*.vars.fqdn, count.index)}."
  type = "A"
  ttl = "300"
  records = ["${element(aws_instance.cluster.*.private_ip, count.index)}"]
}
