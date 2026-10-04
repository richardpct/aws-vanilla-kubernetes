terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.4.1"
    }
    acme = {
      source  = "opentofu/acme"
      version = "3.2.1"
    }
  }
}
