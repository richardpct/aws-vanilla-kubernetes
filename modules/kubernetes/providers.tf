provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

provider "kubectl" {
  config_path = "~/.kube/config-aws"
}

provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config-aws"
  }
}
