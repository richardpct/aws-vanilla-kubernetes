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
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"

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

  depends_on       = [helm_release.calico]

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

  depends_on = [helm_release.calico]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kube-prometheus"

  depends_on = [helm_release.calico]

  set {
    name  = "prometheus.service.port.http"
    value = 80
  }
}

resource "helm_release" "grafana_loki" {
  name       = "grafana-loki"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "grafana-loki"

  depends_on = [helm_release.calico]

  set {
    name  = "global.storageClass"
    value = "longhorn"
  }

  set {
    name  = "compactor.persistence.size"
    value = "1Gi"
  }

  set {
    name  = "ingester.persistence.size"
    value = "1Gi"
  }

  set {
    name  = "querier.persistence.size"
    value = "1Gi"
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "grafana-operator"

  depends_on = [helm_release.calico]

  set {
    name  = "grafana.config.security.admin_password"
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
    name  = "grafana.ingress.host"
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
    name  = "grafana.ingress.tls"
    value = "true"
  }

  set {
    name  = "grafana.ingress.tlsSecret"
    value = "grafana-cert"
  }
}
