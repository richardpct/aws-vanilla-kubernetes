locals {
  ssh_port      = 22
  http_port     = 80
  https_port    = 443
  kube_api_port = 6443
  nodeport_http = 30080
  anywhere      = ["0.0.0.0/0"]
  node_min      = 2
  node_max      = 2
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

variable "instance_type" {
  type        = string
  description = "instance type"
  default     = "t3.small"
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}

variable "my_ip_address" {
  type        = string
  description = "My IP address"
}
