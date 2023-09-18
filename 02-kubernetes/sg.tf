resource "aws_security_group" "kubernetes_master" {
  name   = "sg_kubernetes_master"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes master SG"
  }
}

resource "aws_security_group" "kubernetes_node" {
  name   = "sg_kubernetes_node"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes node SG"
  }
}

resource "aws_security_group" "lb_web" {
  name   = "sg_lb_web"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb_web_sg"
  }
}

resource "aws_security_group_rule" "master_inbound_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_inbound_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "node_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "master_to_node" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "node_to_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "node_to_node" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node.id
  security_group_id        = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "node_from_lb" {
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_web.id
  security_group_id        = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "node_to_lb" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.lb_web.id
  security_group_id        = aws_security_group.kubernetes_node.id
}
