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

resource "null_resource" "get_rook-ceph-operator-values" {
  count = data.terraform_remote_state.servers.outputs.use_rook ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
curl -o /tmp/rook-ceph-operator-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-operator-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-operator-values.yaml
    EOF
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
    "${file("/tmp/rook-ceph-operator-values.yaml")}"
  ]

  depends_on = [null_resource.get_rook-ceph-operator-values]
}

resource "null_resource" "get_rook-ceph-cluster-values" {
  count = data.terraform_remote_state.servers.outputs.use_rook ? 1 : 0
  provisioner "local-exec" {
    command = <<EOF
curl -o /tmp/rook-ceph-cluster-values.yaml https://raw.githubusercontent.com/rook/rook/refs/heads/master/deploy/charts/rook-ceph-cluster/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-cluster-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-cluster-values.yaml
# Issue when using arm64 -> https://github.com/rook/rook/issues/14502
sed -i -e 's/v18.2.4/v18.2.2/' /tmp/rook-ceph-cluster-values.yaml
    EOF
  }

  depends_on = [helm_release.rook-ceph-operator]
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
    "${file("/tmp/rook-ceph-cluster-values.yaml")}"
  ]

  depends_on = [null_resource.get_rook-ceph-cluster-values]
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
