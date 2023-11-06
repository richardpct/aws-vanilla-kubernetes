locals {
  kube_vers      = "1.28"
  helm_vers      = "3.12.3"
  ssh_port       = 22
  https_port     = 443
  kube_api_port  = 6443
  nodeport_http  = 30080
  nodeport_https = 30443
  anywhere       = ["0.0.0.0/0"]
  node_min       = 2
  node_max       = 2
  record_dns     = toset(["www2", "grafana"])
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
  default     = "t3.small"
}

variable "root_size_master" {
  type        = number
  description = "instance master root size"
  default     = 12
}

variable "root_size_node" {
  type        = number
  description = "instance node root size"
  default     = 12
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
