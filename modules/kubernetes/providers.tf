provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

provider "kubectl" {
  config_path = data.terraform_remote_state.servers.outputs.kube_config
}

provider "kubernetes" {
  config_path = data.terraform_remote_state.servers.outputs.kube_config
}

provider "helm" {
  kubernetes = {
    config_path = data.terraform_remote_state.servers.outputs.kube_config
  }
}
