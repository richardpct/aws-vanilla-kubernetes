provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config-aws"
  }
}

resource "kubernetes_secret" "argocd_cert" {
  metadata {
    name = "argocd-tls"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.argocd_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.argocd_private_key
  }
}

resource "helm_release" "argocd" {
  name         = "argocd"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  force_update = true

  set = [
    {
      name  = "configs.params.server\\.insecure"
      value = "true"
    },
    {
      name  = "server.ingress.enabled"
      value = "true"
    },
    {
      name  = "server.ingress.ingressClassName"
      value = "cilium"
    },
    {
      name  = "server.ingress.pathType"
      value = "Prefix"
    },
    {
      name  = "server.ingress.hostname"
      value = "argocd.${var.my_domain}"
    },
    {
      name  = "server.ingress.paths"
      value = "/"
    },
    {
      name  = "server.ingress.extraTls[0].secretName"
      value = "argocd-tls"
    },
    {
      name  = "server.ingress.extraTls[0].hosts[0]"
      value = "argocd.${var.my_domain}"
    }
  ]
}
