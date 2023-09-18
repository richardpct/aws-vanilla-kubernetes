variable "region" {
  type        = string
  description = "Region"
  default     = "eu-west-3"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC cidr block"
  default     = "10.0.0.0/16"
}

variable "subnet_public" {
  type        = string
  description = "Public subnet"
  default     = "10.0.0.0/24"
}

variable "subnet_public_lb_a" {
  type        = string
  description = "Public lb subnet A"
  default     = "10.0.1.0/24"
}

variable "subnet_public_lb_b" {
  type        = string
  description = "Public lb subnet B"
  default     = "10.0.2.0/24"
}

variable "subnet_public_nat_a" {
  type        = string
  description = "Public NAT subnet A"
  default     = "10.0.3.0/24"
}

variable "subnet_public_nat_b" {
  type        = string
  description = "Public NAT subnet B"
  default     = "10.0.4.0/24"
}

variable "subnet_private_a" {
  type        = string
  description = "Private subnet A"
  default     = "10.0.5.0/24"
}

variable "subnet_private_b" {
  type        = string
  description = "Private subnet B"
  default     = "10.0.6.0/24"
}

variable "subnet_private_node_a" {
  type        = string
  description = "Subnet private node A"
  default     = "10.0.7.0/24"
}

variable "subnet_private_node_b" {
  type        = string
  description = "Subnet private node B"
  default     = "10.0.8.0/24"
}
