locals {
  nodeport_http = 30080
}

variable "aws_profile" {
  type        = string
  description = "aws profile"
}

variable "region" {
  type        = string
  description = "Region"
}

variable "env" {
  type        = string
  description = "environment"
}

variable "certificate_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "certificate_remote_state_key" {
  type        = string
  description = "bucket key certificate"
}

variable "servers_remote_state_bucket" {
  type        = string
  description = "bucket"
}

variable "servers_remote_state_key" {
  type        = string
  description = "bucket key servers"
}
