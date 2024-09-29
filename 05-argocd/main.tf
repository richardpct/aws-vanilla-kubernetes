provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes {
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

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "cilium"
  }
  set {
    name  = "server.ingress.pathType"
    value = "Prefix"
  }
  set {
    name  = "server.ingress.hostname"
    value = "argocd.${var.my_domain}"
  }
  set {
    name  = "server.ingress.paths"
    value = "/"
  }
  set {
    name  = "server.ingress.extraTls[0].secretName"
    value = "argocd-tls"
  }
  set {
    name  = "server.ingress.extraTls[0].hosts[0]"
    value = "argocd.${var.my_domain}"
  }
}
