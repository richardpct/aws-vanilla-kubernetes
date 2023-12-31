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

variable "my_domain" {
  type        = string
  description = "domain name"
}
