locals {
  kube_api_port = 6443
  gateway_port  = 30443
  ssh_port      = 22
  nfs_port      = 2049
  http_port     = 80
  https_port    = 443
  anywhere      = ["0.0.0.0/0"]
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

variable "vpc_cidr_block" {
  type        = string
  description = "vpc cidr block"
}

variable "subnet_private" {
  type        = list(string)
  description = "subnet private"
}

variable "subnet_private_efs" {
  type        = list(string)
  description = "subnet private efs"
}

variable "subnet_public" {
  type        = list(string)
  description = "public subnet"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "my_ip_address" {
  type        = string
  description = "my ip address"
}

variable "record_dns" {
  type        = list(string)
  description = "applications list"
}
