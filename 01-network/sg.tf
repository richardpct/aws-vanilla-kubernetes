resource "aws_security_group" "lb_web" {
  name   = "sg_lb_web"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.anywhere
  }

  tags = {
    Name = "lb_web_sg"
  }
}
