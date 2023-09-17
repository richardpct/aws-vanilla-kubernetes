resource "aws_security_group" "kubernetes_server" {
  name   = "sg_k8s_server"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes server SG"
  }
}

resource "aws_security_group" "kubernetes_node" {
  name   = "sg_kubernetes_node"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes node SG"
  }
}

resource "aws_security_group_rule" "server_inbound_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "server_inbound_api" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "server_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "server_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "node_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "server_to_node" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_server.id
  security_group_id        = aws_security_group.kubernetes_node.id
}

resource "aws_security_group_rule" "node_to_server" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node.id
  security_group_id        = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "node_to_node" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node.id
  security_group_id        = aws_security_group.kubernetes_node.id
}
