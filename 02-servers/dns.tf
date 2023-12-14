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
