resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-${local.archi}-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "kubernetes_master" {
  ami                    = data.aws_ami.linux.id
  user_data              = templatefile("user-data-master.sh",
                                        { linux_user       = local.linux_user,
                                          archi            = local.archi,
                                          kube_vers        = local.kube_vers,
                                          helm_vers        = local.helm_vers,
                                          containerd_vers  = local.containerd_vers,
                                          runc_vers        = local.runc_vers })
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

resource "null_resource" "clean_ssh_know_hosts" {
  provisioner "local-exec" {
    command = <<EOF
sed -i -e "/kube.${var.my_domain}/d" ~/.ssh/known_hosts
    EOF
  }
  depends_on = [aws_instance.kubernetes_master]
}

resource "aws_launch_configuration" "kubernetes_worker" {
  name            = "Kubernetes worker"
  image_id        = data.aws_ami.linux.id
  user_data       = templatefile("user-data-worker.sh",
                                 { kubernetes_master_ip = aws_instance.kubernetes_master.private_ip,
                                   archi                = local.archi,
                                   kube_vers            = local.kube_vers,
                                   containerd_vers      = local.containerd_vers,
                                   runc_vers            = local.runc_vers,
                                   nfs_port             = local.nfs_port })

  instance_type   = var.instance_type_worker
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.kubernetes_worker.id]

  ebs_block_device {
    device_name           = "/dev/sdb"
    volume_size           = var.longhorn_size_worker
    volume_type           = "gp2"
    delete_on_termination = true
  }

  root_block_device {
    volume_size           = var.root_size_worker
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_worker" {
  name                 = "Kubernetes worker"
  launch_configuration = aws_launch_configuration.kubernetes_worker.name
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_private_worker[*]
  target_group_arns    = [aws_lb_target_group.http.arn, aws_lb_target_group.https.arn]
  min_size             = local.worker_min
  max_size             = local.worker_max

  tag {
    key                 = "Name"
    value               = "kubernetes worker"
    propagate_at_launch = true
  }
}

resource "aws_eip" "kubernetes_master" {
  instance = aws_instance.kubernetes_master.id
  domain   = "vpc"
}
