locals {
  distribution          = "ubuntu" // amazonlinux or ubuntu
  linux_user            = local.distribution == "ubuntu" ? "ubuntu" : "ec2-user"
  ubuntu_version        = "resolute-26.04"
  #ubuntu_version        = "noble-24.04"
  amazonlinux_version   = "al2023"
  amazonlinux_owner_id  = "137112412989"
  ubuntu_owner_id       = "099720109477"
  archi                 = "amd64" // amd64 or arm64
  bastion_archi         = "amd64" // amd64 or arm64
  ssh_port              = 22
  http_port             = 80
  https_port            = 443
  nfs_port              = 2049
  kube_api_port         = 6443
  hubble_port           = 4245
  nodeport_http         = 30080
  nodeport_https        = 30443
  anywhere              = ["0.0.0.0/0"]
  instance_type_bastion = local.bastion_archi == "arm64" ? "t4g.nano" : "t3.nano"
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

variable "my_ip_address" {
  type        = string
  description = "my ip address"
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}

variable "root_size_master" {
  type        = number
  description = "master instance root size"
  default     = 12
}

variable "root_size_worker" {
  type        = number
  description = "worker instance root size"
  default     = 20
}

variable "add_disk_size_worker" {
  type        = number
  description = "worker instance additional disk size"
  default     = 15
}

variable "rook_version" {
  type        = string
  description = "rook version"
}

variable "record_dns" {
  type        = list(string)
  description = "applications list"
}
