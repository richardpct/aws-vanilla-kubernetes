data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "kube" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "kube"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.kubernetes_master.public_ip]
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = 5

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "www"
  records = [aws_lb.web.dns_name]
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana"
  type    = "CNAME"
  ttl     = 5

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = "grafana"
  records = [aws_lb.web.dns_name]
}
