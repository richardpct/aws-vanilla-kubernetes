provider "kubernetes" {
  config_path = "~/.kube/config-aws"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-aws"
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

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  namespace        = "kube-system"
  force_update     = true

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "ingressController.enabled"
    value = "true"
  }
  set {
    name  = "ingressController.loadbalancerMode"
    value = "shared"
  }
  set {
    name  = "ingressController.service.type"
    value = "NodePort"
  }
  set {
    name  = "ingressController.service.insecureNodePort"
    value = "30080"
  }
  set {
    name  = "ingressController.service.secureNodePort"
    value = "30443"
  }
  set {
    name  = "k8sServiceHost"
    value = data.terraform_remote_state.servers.outputs.kubernetes_api_internal
  }
  set {
    name  = "k8sServicePort"
    value = "6443"
  }
  set {
    name  = "hubble.relay.enabled"
    value = "true"
  }
  set {
    name  = "hubble.ui.enabled"
    value = "true"
  }

  set {
    name  = "encryption.enabled"
    value = "true"
  }

  set {
    name  = "encryption.type"
    value = "wireguard"
  }
}

resource "helm_release" "metrics_server" {
  name         = "metrics-server"
  repository   = "https://kubernetes-sigs.github.io/metrics-server"
  chart        = "metrics-server"
  force_update = true

  depends_on = [helm_release.cilium]

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls=true}"
  }
}

resource "helm_release" "longhorn" {
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  force_update     = true

  depends_on = [helm_release.cilium]
}

#resource "helm_release" "gatekeeper" {
#  name             = "gatekeeper"
#  repository       = "https://open-policy-agent.github.io/gatekeeper/charts"
#  chart            = "gatekeeper"
#  namespace        = "gatekeeper-system"
#  create_namespace = true
#  force_update     = true
#
#  depends_on = [helm_release.longhorn]
#}
