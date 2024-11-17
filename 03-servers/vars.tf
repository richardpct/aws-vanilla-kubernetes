locals {
  distribution          = "ubuntu" // amazonlinux or ubuntu
  linux_user            = local.distribution == "ubuntu" ? "ubuntu" : "ec2-user"
  archi                 = "amd64" // amd64 or arm64
  kube_vers             = "1.31"
  containerd_vers       = "1.7.23"
  runc_vers             = "1.2.1"
  cni_plugins_vers      = "1.6.0"
  kube_bench_vers       = "0.9.1"
  ssh_port              = 22
  http_port             = 80
  https_port            = 443
  nfs_port              = 2049
  kube_api_port         = 6443
  hubble_port           = 4245
  nodeport_http         = 30080
  nodeport_https        = 30443
  anywhere              = ["0.0.0.0/0"]
  instance_type_bastion = local.archi == "arm64" ? "t4g.micro"  : "t3a.nano"
  instance_type_master  = local.archi == "arm64" ? "t4g.small"  : "t3a.small"
  instance_type_worker  = local.archi == "arm64" ? "t4g.small"  : "t3a.small"
  bastion_price         = local.archi == "arm64" ? "0.005" : "0.0025"
  bastion_min           = 1
  bastion_max           = 1
  master_price          = local.archi == "arm64" ? "0.008" : "0.0095"
  master_min            = 3
  master_max            = 3
  worker_price          = local.archi == "arm64" ? "0.008" : "0.0095"
  worker_min            = 3
  worker_max            = 3
  record_dns            = toset(["grafana", "vault", "www2", "argocd"])
}

variable "region" {
  type        = string
  description = "Region"
}

variable "bucket" {
  type        = string
  description = "Bucket"
}

variable "key_network" {
  type        = string
  description = "Network key"
}

variable "root_size_master" {
  type        = number
  description = "instance master root size"
  default     = 12
}

variable "root_size_worker" {
  type        = number
  description = "instance worker root size"
  default     = 15
}

variable "longhorn_size_worker" {
  type        = number
  description = "instance worker longhorn size"
  default     = 15
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}

variable "my_ip_address" {
  type        = string
  description = "My IP address"
}

variable "use_cilium" {
  type        = bool
  description = "Use Cilium or Calico CNI"
  default     = true
}

variable "use_rook" {
  type        = bool
  description = "Use Rook Ceph or Longhorn CSI"
  default     = true
}
