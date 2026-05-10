resource "aws_lb" "external" {
  name               = "lb-external"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_external.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "external_api" {
  name     = "lb-target-group-external-api"
  port     = local.kube_api_port
  protocol = "TCP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "external_api" {
  load_balancer_arn = aws_lb.external.arn
  port              = local.kube_api_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.external_api.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "external_https" {
  name     = "lb-target-group-external-https"
  port     = local.nodeport_https
  protocol = "TCP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "external_https" {
  load_balancer_arn = aws_lb.external.arn
  port              = local.https_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.external_https.arn
    type             = "forward"
  }
}

resource "aws_lb" "internal" {
  name               = "lb-internal"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_internal.id]
  subnets            = aws_subnet.private[*].id
}

resource "aws_lb_target_group" "internal_api" {
  name     = "lb-target-group-internal-api"
  port     = local.kube_api_port
  protocol = "TCP"
  # ec2 can reach out to itself through the NLB
  # see https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-troubleshooting.html
  preserve_client_ip = false
  vpc_id             = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "internal_api" {
  load_balancer_arn = aws_lb.internal.arn
  port              = local.kube_api_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.internal_api.arn
    type             = "forward"
  }
}
