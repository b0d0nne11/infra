variable "root_zone_name"  { }
variable "mailgun_api_key" { }

variable "mailgun_prefix"  { default = "mg" }

provider "aws" {
  region = "us-east-2"
}

provider "mailgun" {
  api_key = "${var.mailgun_api_key}"
}
