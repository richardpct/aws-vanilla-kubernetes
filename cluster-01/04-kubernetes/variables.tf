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
  description = "Certificate key"
}

variable "key_kubernetes" {
  type        = string
  description = "bucket key kubernetes"
}

variable "key_servers" {
  type        = string
  description = "Servers key"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}
