locals {
  linux_user       = "ubuntu"
  kube_vers        = "1.29"
  helm_vers        = "3.13.3"
  containerd_vers  = "1.7.11"
  runc_vers        = "1.1.10"
  cni_plugins_vers = "1.4.0"
  ssh_port         = 22
  http_port        = 80
  https_port       = 443
  nfs_port         = 2049
  kube_api_port    = 6443
  nodeport_http    = 30080
  nodeport_https   = 30443
  anywhere         = ["0.0.0.0/0"]
  node_min         = 2
  node_max         = 2
  record_dns       = toset(["grafana", "vault", "www2"])
}

variable "region" {
  type        = string
  description = "Region"
  default     = "eu-west-3"
}

variable "bucket" {
  type        = string
  description = "Bucket"
}

variable "key_network" {
  type        = string
  description = "Network key"
}

variable "instance_type_master" {
  type        = string
  description = "instance type"
  default     = "t3.medium"
}

variable "instance_type_node" {
  type        = string
  description = "instance type"
  default     = "t3.medium"
}

variable "root_size_master" {
  type        = number
  description = "instance master root size"
  default     = 12
}

variable "root_size_node" {
  type        = number
  description = "instance node root size"
  default     = 15
}

variable "longhorn_size_node" {
  type        = number
  description = "instance node longhorn size"
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
