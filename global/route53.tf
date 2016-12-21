data "aws_route53_zone" "root" {
  count = "${length(var.domains)}"
  name = "${element(split(",", element(var.domains, count.index)), 1)}"
}

resource "aws_route53_zone" "selected" {
  count = "${length(var.domains)}"
  name = "${replace(element(var.domains, count.index), ",", ".")}"
}

resource "aws_route53_record" "selected_NS" {
  count = "${length(var.domains)}"
  zone_id = "${element(data.aws_route53_zone.root.*.zone_id, count.index)}"
  name = "${element(split(",", element(var.domains, count.index)), 0)}"
  type = "NS"
  ttl = "300"
  records = ["${element(aws_route53_zone.selected.*.name_servers, count.index)}"]
}
