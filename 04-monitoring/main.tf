provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-aws"
  }
}

resource "kubernetes_secret" "grafana_cert" {
  metadata {
    name = "grafana-cert"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.grafana_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.grafana_private_key
  }
}

resource "helm_release" "loki-stack" {
  name         = "loki-stack"
  repository   = "https://grafana.github.io/helm-charts"
  chart        = "loki-stack"
  force_update = true

  set {
    name  = "loki.auth_enabled"
    value = "false"
  }
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  set {
    name  = "prometheus.server.persistentVolume.enabled"
    value = "true"
  }
  set {
    name  = "prometheus.server.persistentVolume.size"
    value = "1Gi"
  }
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  set {
    name  = "loki.persistence.enabled"
    value = "true"
  }
  set {
    name  = "loki.persistence.size"
    value = "1Gi"
  }
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_pass
  }
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  set {
    name  = "grafana.ingress.ingressClassName"
    value = "haproxy"
  }
  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana.${var.my_domain}"
  }
  set {
    name  = "grafana.ingress.path"
    value = "/"
  }
  set {
    name  = "grafana.ingress.pathType"
    value = "Prefix"
  }
  set {
    name  = "grafana.ingress.tls[0].secretName"
    value = "grafana-cert"
  }
  set {
    name  = "grafana.ingress.tls[0].hosts[0]"
    value = "grafana.${var.my_domain}"
  }
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }
  set {
    name  = "grafana.persistence.size"
    value = "1Gi"
  }
}
