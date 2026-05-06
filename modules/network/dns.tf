data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.bastion.public_ip]
}

resource "aws_route53_record" "name" {
  count   = length(var.record_dns)
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.record_dns[count.index]
  type    = "CNAME"
  ttl     = 5

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = var.record_dns[count.index]
  records        = [aws_lb.external.dns_name]
}
