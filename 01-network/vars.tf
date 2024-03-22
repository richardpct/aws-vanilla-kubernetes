variable "region" {
  type        = string
  description = "Region"
  default     = "eu-west-3"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC cidr block"
  default     = "192.168.0.0/16"
}

variable "subnet_public" {
  type        = string
  description = "Public subnet"
  default     = "192.168.0.0/24"
}

variable "subnet_public_lb" {
  type        = list(string)
  description = "Public lb subnet"
  default     = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
}

variable "subnet_public_nat" {
  type        = list(string)
  description = "Public NAT subnet"
  default     = ["192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24"]
}

variable "subnet_private_worker" {
  type        = list(string)
  description = "Subnet private worker"
  default     = ["192.168.7.0/24", "192.168.8.0/24", "192.168.9.0/24"]
}
