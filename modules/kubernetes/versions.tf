terraform {
  required_version = ">= 1.13.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "3.6.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.2"
    }
  }
}
