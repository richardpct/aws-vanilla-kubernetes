locals {
  nodeport_http = 30080
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

variable "key_certificate" {
  type        = string
  description = "Certificate key"
}

variable "key_servers" {
  type        = string
  description = "Servers key"
}

variable "grafana_pass" {
  type        = string
  description = "grafana password"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}
