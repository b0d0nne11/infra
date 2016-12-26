resource "random_id" "mailgun_smtp_password" {
  byte_length = 32
}

resource "mailgun_domain" "default" {
  name = "${var.mailgun_prefix}.${var.root_zone_name}"
  smtp_password = "${random_id.mailgun_smtp_password.b64}"
}

data "aws_route53_zone" "mailgun_root" {
  name = "${var.root_zone_name}"
}

resource "aws_route53_zone" "mailgun" {
  name = "${var.mailgun_prefix}.${var.root_zone_name}"
}

resource "aws_route53_record" "mailgun_delegation" {
  zone_id = "${data.aws_route53_zone.mailgun_root.zone_id}"
  name = "${var.mailgun_prefix}"
  type = "NS"
  ttl = "300"
  records = [
    "${aws_route53_zone.mailgun.name_servers[0]}",
    "${aws_route53_zone.mailgun.name_servers[1]}",
    "${aws_route53_zone.mailgun.name_servers[2]}",
    "${aws_route53_zone.mailgun.name_servers[3]}"
  ]
}

resource "aws_route53_record" "mailgun_spf" {
  zone_id = "${aws_route53_zone.mailgun.zone_id}"
  name = ""
  type = "TXT"
  ttl = "300"
  records = ["v=spf1 include:mailgun.org ~all"]
}

resource "aws_route53_record" "mailgun_tracking" {
  zone_id = "${aws_route53_zone.mailgun.zone_id}"
  name = "email"
  type = "CNAME"
  ttl = "300"
  records = ["mailgun.org"]
}

resource "aws_route53_record" "mailgun_mx" {
  zone_id = "${aws_route53_zone.mailgun.zone_id}"
  name = ""
  type = "MX"
  ttl = "300"
  records = [
    "10 mxa.mailgun.org",
    "10 mxb.mailgun.org"
  ]
}
