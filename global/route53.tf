data "aws_route53_zone" "root" {
  name = "${var.root_zone_name}"
}

resource "aws_route53_zone" "dev" {
  name = "dev.${var.root_zone_name}"
}

resource "aws_route53_record" "dev_delegation" {
  zone_id = "${data.aws_route53_zone.root.zone_id}"
  name = "dev"
  type = "NS"
  ttl = "300"
  records = [
    "${aws_route53_zone.dev.name_servers[0]}",
    "${aws_route53_zone.dev.name_servers[1]}",
    "${aws_route53_zone.dev.name_servers[2]}",
    "${aws_route53_zone.dev.name_servers[3]}"
  ]
}
