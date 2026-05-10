locals {
  nodeport_https = 30443
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

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "certificate_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "certificate_remote_state_key" {
  type        = string
  description = "bucket key certificate"
}

variable "network_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "network_remote_state_key" {
  type        = string
  description = "bucket key network"
}

variable "servers_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "servers_remote_state_key" {
  type        = string
  description = "bucket key servers"
}

variable "gateway_api_version" {
  type        = string
  description = "gateway api version"
}
