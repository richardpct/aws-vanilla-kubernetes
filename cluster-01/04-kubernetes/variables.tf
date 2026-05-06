variable "aws_profile" {
  type        = string
  description = "aws profile"
}

variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket where OpenTofu states are stored"
}

variable "key_certificate" {
  type        = string
  description = "bucket certificate key"
}

variable "key_network" {
  type        = string
  description = "bucket network key"
}

variable "key_kubernetes" {
  type        = string
  description = "bucket kubernetes key"
}

variable "key_servers" {
  type        = string
  description = "servers key"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}
