variable "region" {
  type        = string
  description = "Region"
}

variable "bucket" {
  type        = string
  description = "Bucket"
}

variable "key_certificate" {
  type        = string
  description = "Certificate key"
}

variable "grafana_pass" {
  type        = string
  description = "grafana password"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}
