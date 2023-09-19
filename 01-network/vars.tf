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

variable "subnet_public_lb" {
  type        = list(string)
  description = "Public lb subnet"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "subnet_public_nat" {
  type        = list(string)
  description = "Public NAT subnet"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "subnet_private_node" {
  type        = list(string)
  description = "Subnet private node"
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}
