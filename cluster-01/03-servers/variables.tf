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

variable "key_network" {
  type        = string
  description = "bucket key network"
}

variable "key_servers" {
  type        = string
  description = "bucket key servers"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "ssh_public_key" {
  type        = string
  description = "ssh public key"
}
