resource "aws_lb" "web" {
  name               = "lb-web"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_web.id]
  subnets            = data.terraform_remote_state.network.outputs.subnet_public_lb[*]
}

resource "aws_lb_target_group" "http" {
  name     = "lb-target-group-http"
  port     = local.nodeport_http
  protocol = "TCP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = local.http_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.http.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "https" {
  name     = "lb-target-group-https"
  port     = local.nodeport_https
  protocol = "TCP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = local.https_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.https.arn
    type             = "forward"
  }
}
