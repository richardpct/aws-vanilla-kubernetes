resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "kubernetes_server" {
  name   = "sg_k8s_server"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes server SG"
  }
}

resource "aws_security_group" "kubernetes_node01" {
  name   = "sg_k8s_node01"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes node 01 SG"
  }
}

resource "aws_security_group" "kubernetes_node02" {
  name   = "sg_k8s_node02"
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "Kubernetes node 02 SG"
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

resource "aws_security_group_rule" "node01_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_node01.id
}

resource "aws_security_group_rule" "node02_inbound_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.kubernetes_node02.id
}

//resource "aws_security_group_rule" "node01_inbound_http" {
//  type              = "ingress"
//  from_port         = 30123
//  to_port           = 30123
//  protocol          = "tcp"
//  cidr_blocks       = [var.my_ip_address]
//  security_group_id = aws_security_group.kubernetes_node01.id
//}
//
//resource "aws_security_group_rule" "node02_inbound_http" {
//  type              = "ingress"
//  from_port         = 30123
//  to_port           = 30123
//  protocol          = "tcp"
//  cidr_blocks       = [var.my_ip_address]
//  security_group_id = aws_security_group.kubernetes_node02.id
//}

resource "aws_security_group_rule" "server_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "node01_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_node01.id
}

resource "aws_security_group_rule" "node02_outbound_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kubernetes_node02.id
}

resource "aws_security_group_rule" "server_to_node01" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_server.id
  security_group_id        = aws_security_group.kubernetes_node01.id
}

resource "aws_security_group_rule" "server_to_node02" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_server.id
  security_group_id        = aws_security_group.kubernetes_node02.id
}

resource "aws_security_group_rule" "node01_to_server" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node01.id
  security_group_id        = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "node02_to_server" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node02.id
  security_group_id        = aws_security_group.kubernetes_server.id
}

resource "aws_security_group_rule" "node01_to_node02" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node01.id
  security_group_id        = aws_security_group.kubernetes_node02.id
}

resource "aws_security_group_rule" "node02_to_node01" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_node02.id
  security_group_id        = aws_security_group.kubernetes_node01.id
}

resource "aws_instance" "kubernetes_server" {
  ami                    = var.image_id
  user_data              = "${file("user-data-server.sh")}"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_public_id
  vpc_security_group_ids = [aws_security_group.kubernetes_server.id]

  tags = {
    Name = "Kubernetes Server"
  }
}

resource "aws_instance" "kubernetes_node01" {
  ami                    = var.image_id
  user_data              = templatefile("user-data-node.sh", { kubernetes_server_ip = aws_instance.kubernetes_server.private_ip })
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_public_id
  vpc_security_group_ids = [aws_security_group.kubernetes_node01.id]

  tags = {
    Name = "kubernetes node01"
  }
}

resource "aws_instance" "kubernetes_node02" {
  ami                    = var.image_id
  user_data              = templatefile("user-data-node.sh", { kubernetes_server_ip = aws_instance.kubernetes_server.private_ip })
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_public_id
  vpc_security_group_ids = [aws_security_group.kubernetes_node02.id]

  tags = {
    Name = "kubernetes node02"
  }
}

resource "aws_eip" "kubernetes_server" {
  instance = aws_instance.kubernetes_server.id
  vpc      = true
}

resource "aws_eip" "kubernetes_node01" {
  instance = aws_instance.kubernetes_node01.id
  vpc      = true
}

resource "aws_eip" "kubernetes_node02" {
  instance = aws_instance.kubernetes_node02.id
  vpc      = true
}
