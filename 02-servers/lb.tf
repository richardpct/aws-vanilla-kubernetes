resource "aws_lb" "web" {
  name               = "lb-web"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb_web.id]
  subnets            = data.terraform_remote_state.network.outputs.subnet_public_lb[*]
}

resource "aws_lb_target_group" "web" {
  port     = local.nodeport_https
  protocol = "TCP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = local.https_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.web.arn
    type             = "forward"
  }
}
