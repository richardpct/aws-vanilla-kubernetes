resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "amazonlinux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.distribution == "ubuntu" ? "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-oracular-24.10-${local.archi}-minimal-*" : "al2023-ami-*-kernel-*-${local.archi}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.distribution == "ubuntu" ? "099720109477" : "137112412989"]
}

data "aws_ami" "bastion_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.distribution == "ubuntu" ? "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-oracular-24.10-${local.bastion_archi}-minimal-*" : "al2023-ami-*-kernel-*-${local.bastion_archi}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.distribution == "ubuntu" ? "099720109477" : "137112412989"]
}

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "eip_bastion"
  }
}

resource "aws_launch_template" "bastion" {
  name      = "bastion"
  image_id  = data.aws_ami.bastion_linux.id
  user_data = base64encode(templatefile("${local.distribution}/user-data-bastion.sh",
                                        { eip_bastion_id = aws_eip.bastion.id,
                                          efs_dns_name   = aws_efs_file_system.efs.dns_name,
                                          nfs_port       = local.nfs_port,
                                          region         = var.region,
                                          archi          = local.bastion_archi }))
  instance_type = local.instance_type_bastion
  key_name      = aws_key_pair.deployer.key_name

  network_interfaces {
    security_groups             = [aws_security_group.bastion.id]
    associate_public_ip_address = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      max_price = local.bastion_price
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion" {
  name                 = "asg_bastion"
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_public[*]
  min_size             = local.bastion_min
  max_size             = local.bastion_max

  launch_template {
    id = aws_launch_template.bastion.id
  }

  tag {
    key                 = "Name"
    value               = "bastion"
    propagate_at_launch = true
  }
}

resource "aws_launch_template" "kubernetes_master" {
  name      = "Kubernetes_master"
  image_id  = data.aws_ami.linux.id
  user_data = base64encode(templatefile("${local.distribution}/user-data-master.sh",
                                        { linux_user        = local.linux_user,
                                          archi             = local.archi,
                                          nfs_port          = local.nfs_port,
                                          worker_nb         = local.worker_min,
                                          efs_dns_name      = aws_efs_file_system.efs.dns_name,
                                          kube_api_internet = aws_lb.internet.dns_name,
                                          kube_api_internal = aws_lb.api_internal.dns_name,
                                          use_cilium        = var.use_cilium }))
  instance_type = local.instance_type_master
  key_name      = aws_key_pair.deployer.key_name

  network_interfaces {
    security_groups = [aws_security_group.kubernetes_master.id]
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      max_price = local.master_price
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_master" {
  name                = "Kubernetes master"
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.subnet_private[*]
  target_group_arns   = [aws_lb_target_group.api.arn, aws_lb_target_group.api_internal.arn]
  min_size            = local.master_min
  max_size            = local.master_max

  launch_template {
    id = aws_launch_template.kubernetes_master.id
  }

  tag {
    key                 = "Name"
    value               = "kubernetes master"
    propagate_at_launch = true
  }
}

resource "null_resource" "get_kube_config" {
  provisioner "local-exec" {
    command = <<EOF
while ! nc -w1 ${aws_eip.bastion.public_ip} ${local.ssh_port}; do sleep 10; done
ssh -o StrictHostKeyChecking=accept-new ${local.linux_user}@${aws_eip.bastion.public_ip} 'until [ -f /nfs/config ]; do sleep 10; done'
ssh ${local.linux_user}@${aws_eip.bastion.public_ip} 'sed -e "s;https://.*:6443;https://${aws_lb.internet.dns_name}:6443;" /nfs/config' > ~/.kube/config-aws
ssh ${local.linux_user}@${aws_eip.bastion.public_ip} 'sudo umount /nfs'
chmod 600 ~/.kube/config-aws
    EOF
  }

  depends_on = [aws_autoscaling_group.bastion]
}

resource "null_resource" "clean_ssh_know_hosts" {
  provisioner "local-exec" {
    command = <<EOF
sed -i -e "/bastion.${var.my_domain}/d" ~/.ssh/known_hosts
    EOF
  }
  depends_on = [aws_autoscaling_group.bastion]
}

resource "aws_launch_template" "kubernetes_worker" {
  name      = "Kubernetes_worker"
  image_id  = data.aws_ami.linux.id
  user_data = base64encode(templatefile("${local.distribution}/user-data-worker.sh",
                                        { archi        = local.archi,
                                          use_rook     = var.use_rook,
                                          nfs_port     = local.nfs_port,
                                          efs_dns_name = aws_efs_file_system.efs.dns_name }))
  instance_type = local.instance_type_worker
  key_name      = aws_key_pair.deployer.key_name

  block_device_mappings {
    device_name = data.aws_ami.linux.root_device_name

    ebs {
      volume_size           = var.root_size_worker
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  block_device_mappings {
    device_name = "/dev/sdb"

    ebs {
      volume_size           = var.longhorn_size_worker
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  network_interfaces {
    security_groups = [aws_security_group.kubernetes_worker.id]
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      max_price = local.worker_price
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kubernetes_worker" {
  name                 = "Kubernetes worker"
  vpc_zone_identifier  = data.terraform_remote_state.network.outputs.subnet_private[*]
  target_group_arns    = [aws_lb_target_group.https.arn]
  min_size             = local.worker_min
  max_size             = local.worker_max

  launch_template {
    id = aws_launch_template.kubernetes_worker.id
  }

  tag {
    key                 = "Name"
    value               = "kubernetes worker"
    propagate_at_launch = true
  }
}

resource "null_resource" "get_rook-ceph-operator-values" {
  count = var.use_rook ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-operator-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-operator-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-operator-values.yaml
    EOF
  }
}

resource "null_resource" "get_rook-ceph-cluster-values" {
  count = var.use_rook ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-cluster-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph-cluster/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-cluster-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-cluster-values.yaml
# Issue when using arm64 -> https://github.com/rook/rook/issues/14502
sed -i -e 's/v18.2.4/v18.2.2/' /tmp/rook-ceph-cluster-values.yaml
    EOF
  }
}
