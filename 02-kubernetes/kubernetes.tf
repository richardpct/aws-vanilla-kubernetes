provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-aws"
  }
}

resource "helm_release" "calico" {
  name             = "projectcalico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true

  depends_on       = [null_resource.get_kube_config]
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

  depends_on       = [helm_release.metrics_server]

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

resource "helm_release" "nfs_storage" {
  name       = "nfs-subdir-external-provisioner"
  repository = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart      = "nfs-subdir-external-provisioner"

  depends_on = [helm_release.haproxy_ingress]

  set {
    name  = "nfs.server"
    value = aws_instance.kubernetes_master.private_ip
  }

  set {
    name  = "nfs.path"
    value = "/nfs"
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "kube-prometheus"

  depends_on = [helm_release.nfs_storage]

  set {
    name  = "prometheus.service.port.http"
    value = 80
  }
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "grafana-operator"

  depends_on = [helm_release.prometheus]

  set {
    name  = "grafana.config.security.admin_password"
    value = "xxxxx"
  }
}