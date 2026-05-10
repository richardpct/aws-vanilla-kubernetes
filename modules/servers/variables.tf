locals {
  distribution          = "amazonlinux" // amazonlinux or ubuntu
  linux_user            = local.distribution == "ubuntu" ? "ubuntu" : "ec2-user"
  ubuntu_version        = "resolute-26.04"
  amazonlinux_version   = "al2023"
  amazonlinux_owner_id  = "137112412989"
  ubuntu_owner_id       = "099720109477"
  archi                 = "amd64" // amd64 or arm64
  amazonlinux_archi     = local.archi == "amd64" ? "x86_64" : "arm64"
  ssh_port              = 22
  nfs_port              = 2049
  instance_type_bastion = local.archi == "arm64" ? "t4g.nano" : "t3.nano"
  bastion_price         = local.archi == "arm64" ? "0.0025" : "0.001"
  bastion_min           = 1
  bastion_max           = 1
  instance_type_master  = local.archi == "arm64" ? "t4g.small" : "t3.small"
  master_price          = local.archi == "arm64" ? "0.010" : "0.010"
  master_min            = 3
  master_max            = 3
  instance_type_worker  = local.archi == "arm64" ? "t4g.medium" : "t3.medium"
  worker_price          = local.archi == "arm64" ? "0.025" : "0.020"
  worker_min            = 3
  worker_max            = 3
}

variable "aws_profile" {
  type        = string
  description = "aws profile"
}

variable "region" {
  type        = string
  description = "region"
}

variable "env" {
  type        = string
  description = "environment"
}

variable "network_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "network_remote_state_key" {
  type        = string
  description = "bucket network key"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}

variable "root_size_master" {
  type        = number
  description = "master instance root size"
  default     = 8
}

variable "root_size_worker" {
  type        = number
  description = "worker instance root size"
  default     = 20
}

variable "add_disk_size_worker" {
  type        = number
  description = "worker instance additional disk size for rook ceph"
  default     = 15
}

variable "rook_version" {
  type        = string
  description = "rook version"
}

variable "kube_config" {
  type        = string
  description = "kube config path"
}
