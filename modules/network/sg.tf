# bastion
resource "aws_security_group" "bastion" {
  name   = "sg_bastion"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_bastion"
  }
}

resource "aws_security_group_rule" "bastion_from_allow_ssh" {
  type              = "ingress"
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_any_http" {
  type              = "egress"
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = "tcp"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_any_https" {
  type              = "egress"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = "tcp"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_master_ssh" {
  type                     = "egress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_worker_ssh" {
  type                     = "egress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_efs_nfs" {
  type                     = "egress"
  from_port                = local.nfs_port
  to_port                  = local.nfs_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.efs.id
  security_group_id        = aws_security_group.bastion.id
}

# kubernetes master
resource "aws_security_group" "kubernetes_master" {
  name   = "sg_kubernetes_master"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_kubernetes_master"
  }
}

resource "aws_security_group_rule" "master_from_bastion_ssh" {
  type                     = "ingress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_from_worker_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_from_master_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_from_lb_external_api" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_external.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_from_lb_internal_api" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_internal.id
  security_group_id        = aws_security_group.kubernetes_master.id
}

resource "aws_security_group_rule" "master_to_any_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.kubernetes_master.id
}

# kubernetes worker
resource "aws_security_group" "kubernetes_worker" {
  name   = "sg_kubernetes_worker"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_kubernetes_worker"
  }
}

resource "aws_security_group_rule" "worker_from_bastion_ssh" {
  type                     = "ingress"
  from_port                = local.ssh_port
  to_port                  = local.ssh_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "worker_from_master" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "worker_from_worker" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "worker_from_lb_internal_api" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_internal.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "worker_from_lb_external_nodeport" {
  type                     = "ingress"
  from_port                = local.nodeport_https
  to_port                  = local.nodeport_https
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_external.id
  security_group_id        = aws_security_group.kubernetes_worker.id
}

resource "aws_security_group_rule" "worker_to_any_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.kubernetes_worker.id
}

# efs
resource "aws_security_group" "efs" {
  name   = "sg_efs"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_efs"
  }
}

resource "aws_security_group_rule" "efs_from_bastion_nfs" {
  type                     = "ingress"
  from_port                = local.nfs_port
  to_port                  = local.nfs_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.efs.id
}

resource "aws_security_group_rule" "efs_from_master_nfs" {
  type                     = "ingress"
  from_port                = local.nfs_port
  to_port                  = local.nfs_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.efs.id
}

resource "aws_security_group_rule" "efs_from_worker_nfs" {
  type                     = "ingress"
  from_port                = local.nfs_port
  to_port                  = local.nfs_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.efs.id
}

# lb external
resource "aws_security_group" "lb_external" {
  name   = "sg_lb_external"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_lb_external"
  }
}

resource "aws_security_group_rule" "lb_external_from_allow_api" {
  type              = "ingress"
  from_port         = local.kube_api_port
  to_port           = local.kube_api_port
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.lb_external.id
}

resource "aws_security_group_rule" "lb_external_from_allow_https" {
  type              = "ingress"
  from_port         = local.https_port
  to_port           = local.https_port
  protocol          = "tcp"
  cidr_blocks       = [var.my_ip_address]
  security_group_id = aws_security_group.lb_external.id
}

resource "aws_security_group_rule" "lb_external_to_any_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.lb_external.id
}

# lb internal
resource "aws_security_group" "lb_internal" {
  name   = "sg_lb_internal"
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "sg_lb_internal"
  }
}

resource "aws_security_group_rule" "lb_internal_from_master_api" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_master.id
  security_group_id        = aws_security_group.lb_internal.id
}

resource "aws_security_group_rule" "lb_internal_from_worker_api" {
  type                     = "ingress"
  from_port                = local.kube_api_port
  to_port                  = local.kube_api_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kubernetes_worker.id
  security_group_id        = aws_security_group.lb_internal.id
}

resource "aws_security_group_rule" "lb_internal_to_any_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = local.anywhere
  security_group_id = aws_security_group.lb_internal.id
}
