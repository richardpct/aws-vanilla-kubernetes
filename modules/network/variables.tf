variable "aws_profile" {
  type        = string
  description = "aws profile"
}

variable "region" {
  type        = string
  description = "region"
}

variable "env" {
  type        = string
  description = "environment"
}

variable "vpc_cidr_block" {
  type        = string
  description = "vpc cidr block"
}

variable "subnet_private" {
  type        = list(string)
  description = "subnet private"
}

variable "subnet_public" {
  type        = list(string)
  description = "public subnet"
}
