resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
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
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_private_node_a
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
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_private_node_b
  vpc_security_group_ids = [aws_security_group.kubernetes_node02.id]

  tags = {
    Name = "kubernetes node02"
  }
}

resource "aws_eip" "kubernetes_server" {
  instance = aws_instance.kubernetes_server.id
  vpc      = true
}
