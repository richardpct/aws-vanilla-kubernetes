resource "aws_lb" "external" {
  name               = "lb-external"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_external.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "api" {
  name     = "lb-target-group-api"
  port     = local.kube_api_port
  protocol = "TCP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.external.arn
  port              = local.kube_api_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.api.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "https" {
  name     = "lb-target-group-https"
  port     = local.nodeport_https
  protocol = "TCP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.external.arn
  port              = local.https_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.https.arn
    type             = "forward"
  }
}

resource "aws_lb" "api_internal" {
  name                = "lb-api-internal"
  internal            = true
  load_balancer_type  = "network"
  security_groups     = [aws_security_group.lb_api_internal.id]
  subnets             = aws_subnet.private[*].id
}

resource "aws_lb_target_group" "api_internal" {
  name               = "lb-target-group-api-internal"
  port               = local.kube_api_port
  protocol           = "TCP"
  # ec2 can reach out to itself through the NLB
  # see https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-troubleshooting.html
  preserve_client_ip = false
  vpc_id             = aws_vpc.my_vpc.id
}

resource "aws_lb_listener" "api_internal" {
  load_balancer_arn = aws_lb.api_internal.arn
  port              = local.kube_api_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.api_internal.arn
    type             = "forward"
  }
}
