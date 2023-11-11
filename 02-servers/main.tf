resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "debian" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["136693071363"] # Debian
}

resource "aws_instance" "kubernetes_master" {
  ami                    = data.aws_ami.debian.id
  user_data              = templatefile("user-data-master.sh",
                                        { linux_user = local.linux_user,
                                          kube_vers  = local.kube_vers,
                                          helm_vers  = local.helm_vers })
  instance_type          = var.instance_type_master
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = data.terraform_remote_state.network.outputs.subnet_public_id
  vpc_security_group_ids = [aws_security_group.kubernetes_master.id]

  root_block_device {
    volume_size           = var.root_size_master
    delete_on_termination = true
  }

  tags = {
    Name = "Kubernetes master"
  }
}

data "aws_instance" "kubernetes_master" {
  filter {
    name   = "tag:Name"
    values = ["Kubernetes master"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_instance.kubernetes_master]
}

resource "null_resource" "get_kube_config" {
  provisioner "local-exec" {
    command = <<EOF
aws ec2 wait instance-status-ok --instance-ids ${data.aws_instance.kubernetes_master.host_id}
ssh -o StrictHostKeyChecking=accept-new ${local.linux_user}@${aws_eip.kubernetes_master.public_ip} 'until [ -f .kube/config ]; do sleep 1; done'
ssh ${local.linux_user}@${aws_eip.kubernetes_master.public_ip} 'sed -e "s;https://.*:6443;https://${aws_eip.kubernetes_master.public_ip}:6443;" .kube/config' > ~/.kube/config-aws
chmod 600 ~/.kube/config-aws
    EOF
  }

  depends_on = [aws_instance.kubernetes_master]
}

resource "aws_launch_configuration" "kubernetes_node" {
  name            = "Kubernetes node"
  image_id        = data.aws_ami.debian.id
  user_data       = templatefile("user-data-node.sh",
                                 { kubernetes_master_ip = aws_instance.kubernetes_master.private_ip,
                                   kube_vers = local.kube_vers })
  instance_type   = var.instance_type_node
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.kubernetes_node.id]

  root_block_device {
    volume_size           = var.root_size_node
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_node" {
  name                 = "Kubernetes node"
  launch_configuration = aws_launch_configuration.kubernetes_node.name
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_private_node[*]
  target_group_arns    = [aws_lb_target_group.web.arn]
  min_size             = local.node_min
  max_size             = local.node_max

  tag {
    key                 = "Name"
    value               = "kubernetes node"
    propagate_at_launch = true
  }
}

resource "aws_eip" "kubernetes_master" {
  instance = aws_instance.kubernetes_master.id
  domain   = "vpc"
}

resource "null_resource" "reboot_kube_master" {
  provisioner "local-exec" {
    command = <<EOF
ssh ${local.linux_user}@${aws_eip.kubernetes_master.public_ip} 'if [ -f /var/run/reboot-required ]; then sudo shutdown -r now; fi'
    EOF
  }

  depends_on = [null_resource.get_kube_config]
}
