resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "kubernetes_master" {
  ami                    = var.image_id
  user_data              = "${file("user-data-master.sh")}"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_public_id
  vpc_security_group_ids = [aws_security_group.kubernetes_master.id]

  tags = {
    Name = "Kubernetes master"
  }
}

resource "aws_launch_configuration" "kubernetes_node" {
  name            = "Kubernetes node"
  image_id        = var.image_id
  user_data       = templatefile("user-data-node.sh", { kubernetes_master_ip = aws_instance.kubernetes_master.private_ip })
  instance_type   = var.instance_type
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.kubernetes_node.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_node" {
  name                 = "Kubernetes node"
  launch_configuration = aws_launch_configuration.kubernetes_node.name
  vpc_zone_identifier  = [data.terraform_remote_state.network.outputs.subnet_private_node_a, data.terraform_remote_state.network.outputs.subnet_private_node_b]
  min_size             = 2
  max_size             = 2

  tag {
    key                 = "Name"
    value               = "kubernetes node"
    propagate_at_launch = true
  }
}

resource "aws_eip" "kubernetes_master" {
  instance = aws_instance.kubernetes_master.id
  vpc      = true
}
