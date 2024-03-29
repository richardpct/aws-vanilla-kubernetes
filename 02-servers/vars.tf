locals {
  linux_user      = "ubuntu"
  archi           = "arm64" // amd64 or arm64
  kube_vers       = "1.29"
  helm_vers       = "3.14.0"
  containerd_vers = "1.7.13"
  runc_vers       = "1.1.12"
  ssh_port        = 22
  http_port       = 80
  https_port      = 443
  nfs_port        = 2049
  kube_api_port   = 6443
  hubble_port     = 4245
  nodeport_http   = 30080
  nodeport_https  = 30443
  anywhere        = ["0.0.0.0/0"]
  worker_price    = "0.015"
  worker_min      = 2
  worker_max      = 2
  record_dns      = toset(["grafana", "vault", "www2"])
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
  default     = "t4g.small"
}

variable "instance_type_worker" {
  type        = string
  description = "instance type"
  default     = "t4g.medium"
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
