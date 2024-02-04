provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-aws"
  }
}

resource "kubernetes_secret" "vault_cert" {
  metadata {
    name = "vault-cert"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.vault_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.vault_private_key
  }
}

resource "helm_release" "vault" {
  name         = "vault"
  repository   = "https://helm.releases.hashicorp.com"
  chart        = "vault"
  force_update = true

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
    name  = "server.ingress.hosts[0].host"
    value = "vault.${var.my_domain}"
  }
  set {
    name  = "server.ingress.hosts[0].paths[0]"
    value = "/"
  }
  set {
    name  = "server.ingress.tls[0].secretName"
    value = "vault-cert"
  }
  set {
    name  = "server.ingress.tls[0].hosts[0]"
    value = "vault.${var.my_domain}"
  }
  set {
    name  = "server.dataStorage.size"
    value = "1Gi"
  }
}
