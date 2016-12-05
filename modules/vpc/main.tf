variable "env_name"             { }
variable "azs"                  { type = "list" }
variable "vpc_cidr"             { }
variable "public_cidrs"         { type = "list" }

variable "enable_dns_hostnames" { default = true }
variable "enable_dns_support"   { default = true }

resource "aws_vpc" "default" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support = "${var.enable_dns_support}"
  tags {
    Name = "${var.env_name}-vpc"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
  tags {
    Name = "${var.env_name}-gtw"
  }
}

resource "aws_subnet" "public" {
  count = "${length(var.public_cidrs)}"
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "${element(var.public_cidrs, count.index)}"
  availability_zone = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.env_name}-public-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.default.id}"
  tags {
    Name = "${var.env_name}-public"
  }
}

resource "aws_route" "public_gtw" {
  route_table_id = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_route_table_association" "public" {
  count = "${length(var.public_cidrs)}"
  route_table_id = "${aws_route_table.public.id}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
}

output "id" {
  value = "${aws_vpc.default.id}"
}

output "public_subnet_ids" {
  value = ["${aws_subnet.public.*.id}"]
}
