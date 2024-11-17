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
  count            = data.terraform_remote_state.servers.outputs.use_cilium ? 1 : 0
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

resource "helm_release" "calico" {
  count            = data.terraform_remote_state.servers.outputs.use_cilium ? 0 : 1
  name             = "projectcalico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true
  force_update     = true
}

resource "helm_release" "haproxy_ingress" {
  count            = data.terraform_remote_state.servers.outputs.use_cilium ? 0 : 1
  name             = "haproxytech"
  repository       = "https://haproxytech.github.io/helm-charts"
  chart            = "kubernetes-ingress"
  namespace        = "haproxy-controller"
  create_namespace = true
  force_update     = true

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

resource "helm_release" "metrics_server" {
  name         = "metrics-server"
  repository   = "https://kubernetes-sigs.github.io/metrics-server"
  chart        = "metrics-server"
  force_update = true

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls=true}"
  }
}

resource "helm_release" "rook-ceph-operator" {
  count            = data.terraform_remote_state.servers.outputs.use_rook ? 1 : 0
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm-charts/rook-ceph-operator-values.yaml")}"
  ]
}

resource "helm_release" "rook-ceph-cluster" {
  count            = data.terraform_remote_state.servers.outputs.use_rook ? 1 : 0
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm-charts/rook-ceph-cluster-values.yaml")}"
  ]

  depends_on = [helm_release.rook-ceph-operator]
}

resource "helm_release" "longhorn" {
  count            = data.terraform_remote_state.servers.outputs.use_rook ? 0 : 1
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  force_update     = true

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
