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

variable "image_id" {
  type        = string
  description = "image id"
  default     = "ami-0f2c91ec8df4bde48" // Ubuntu
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
