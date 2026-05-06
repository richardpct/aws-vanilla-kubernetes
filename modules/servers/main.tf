data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    profile = var.aws_profile
    bucket  = var.network_remote_state_bucket
    key     = var.network_remote_state_key
    region  = var.region
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

data "aws_ami" "linux" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.distribution == "ubuntu" ? "ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-${local.ubuntu_version}-${local.archi}-minimal-*" : "${local.amazonlinux_version}-ami-*-kernel-*-${local.amazonlinux_archi}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.distribution == "ubuntu" ? local.ubuntu_owner_id : local.amazonlinux_owner_id]
}

resource "aws_launch_template" "bastion" {
  name      = "bastion"
  image_id  = data.aws_ami.linux.id
  user_data = base64encode(templatefile("${path.module}/${local.distribution}/user-data-bastion.sh",
                                        { eip_bastion_id = data.terraform_remote_state.network.outputs.aws_eip_bastion_id,
                                          efs_dns_name   = aws_efs_file_system.efs.dns_name,
                                          region         = var.region }))
  instance_type = local.instance_type_bastion
  key_name      = aws_key_pair.deployer.key_name

  network_interfaces {
    security_groups             = [data.terraform_remote_state.network.outputs.aws_security_group_bastion_id]
    associate_public_ip_address = true
  }

  iam_instance_profile {
    name = data.terraform_remote_state.network.outputs.aws_iam_instance_profile_name
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
  user_data = base64encode(templatefile("${path.module}/${local.distribution}/user-data-master.sh",
                                        { linux_user        = local.linux_user,
                                          archi             = local.archi,
                                          nfs_port          = local.nfs_port,
                                          efs_dns_name      = aws_efs_file_system.efs.dns_name,
                                          kube_api_external = data.terraform_remote_state.network.outputs.aws_lb_external_dns_name,
                                          kube_api_internal = data.terraform_remote_state.network.outputs.aws_lb_api_internal_dns_name }))
  instance_type = local.instance_type_master
  key_name      = aws_key_pair.deployer.key_name

  block_device_mappings {
    device_name = data.aws_ami.linux.root_device_name

    ebs {
      volume_size           = var.root_size_master
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  network_interfaces {
    security_groups = [data.terraform_remote_state.network.outputs.aws_security_group_kubernetes_master_id]
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
  target_group_arns   = [data.terraform_remote_state.network.outputs.aws_lb_target_group_api_arn,
                         data.terraform_remote_state.network.outputs.aws_lb_target_group_api_internal_arn]
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
while ! nc -w1 ${data.terraform_remote_state.network.outputs.aws_eip_bastion_ip} ${local.ssh_port}; do sleep 10; done
ssh -o StrictHostKeyChecking=accept-new ${local.linux_user}@${data.terraform_remote_state.network.outputs.aws_eip_bastion_ip} 'until [ -f /nfs/config ]; do sleep 10; done'
[ -d ~/.kube ] || mkdir ~/.kube
ssh ${local.linux_user}@${data.terraform_remote_state.network.outputs.aws_eip_bastion_ip} 'sed -e "s;https://.*:6443;https://${data.terraform_remote_state.network.outputs.aws_lb_external_dns_name}:6443;" /nfs/config' > ~/.kube/config-aws
ssh ${local.linux_user}@${data.terraform_remote_state.network.outputs.aws_eip_bastion_ip} 'sudo umount /nfs'
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
  user_data = base64encode(templatefile("${path.module}/${local.distribution}/user-data-worker.sh",
                                        { archi             = local.archi,
                                          nfs_port          = local.nfs_port,
                                          efs_dns_name      = aws_efs_file_system.efs.dns_name }))
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
      volume_size           = var.add_disk_size_worker
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  network_interfaces {
    security_groups = [data.terraform_remote_state.network.outputs.aws_security_group_kubernetes_worker_id]
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
  target_group_arns    = [data.terraform_remote_state.network.outputs.aws_lb_target_group_https_arn]
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
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-operator-values.yaml https://raw.githubusercontent.com/rook/rook/refs/tags/v${var.rook_version}/deploy/charts/rook-ceph/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-operator-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-operator-values.yaml
    EOF
  }
}

resource "null_resource" "get_rook-ceph-cluster-values" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-cluster-values.yaml https://raw.githubusercontent.com/rook/rook/refs/tags/v${var.rook_version}/deploy/charts/rook-ceph-cluster/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-cluster-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-cluster-values.yaml
    EOF
  }
}
