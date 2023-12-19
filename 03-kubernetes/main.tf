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


resource "kubernetes_secret" "www2_cert" {
  metadata {
    name = "www2-cert"
  }

  type = "tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.www2_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.www2_private_key
  }
}

resource "helm_release" "calico" {
  name             = "projectcalico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true
  force_update     = true

  depends_on = [kubernetes_secret.grafana_cert]
}

resource "helm_release" "metrics_server" {
  name         = "metrics-server"
  repository   = "https://kubernetes-sigs.github.io/metrics-server"
  chart        = "metrics-server"
  force_update = true

  depends_on = [helm_release.calico]

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls=true}"
  }
}

resource "helm_release" "haproxy_ingress" {
  name             = "haproxytech"
  repository       = "https://haproxytech.github.io/helm-charts"
  chart            = "kubernetes-ingress"
  namespace        = "haproxy-controller"
  create_namespace = true
  force_update     = true

  depends_on = [helm_release.calico]

  set {
    name  = "controller.service.nodePorts.http"
    value = local.nodeport_http
  }
  set {
    name  = "controller.service.nodePorts.https"
    value = 30443
  }
  set {
    name  = "controller.service.nodePorts.stat"
    value = 30002
  }
}

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  force_update     = true

  depends_on = [helm_release.calico]
}

resource "helm_release" "loki-stack" {
  name         = "loki-stack"
  repository   = "https://grafana.github.io/helm-charts"
  chart        = "loki-stack"
  force_update = true

  depends_on = [helm_release.longhorn]

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

resource "helm_release" "vault" {
  name         = "vault"
  repository   = "https://helm.releases.hashicorp.com"
  chart        = "vault"
  force_update = true

  depends_on = [helm_release.calico]

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }
  set {
    name  = "server.ingress.ingressClassName"
    value = "haproxy"
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
