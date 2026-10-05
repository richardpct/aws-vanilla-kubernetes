data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    profile = var.aws_profile
    bucket  = var.certificate_remote_state_bucket
    key     = var.certificate_remote_state_key
    region  = var.region
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    profile = var.aws_profile
    bucket  = var.network_remote_state_bucket
    key     = var.network_remote_state_key
    region  = var.region
  }
}

data "terraform_remote_state" "servers" {
  backend = "s3"

  config = {
    profile = var.aws_profile
    bucket  = var.servers_remote_state_bucket
    key     = var.servers_remote_state_key
    region  = var.region
  }
}

resource "kubernetes_secret_v1" "default_tls_cert" {
  metadata {
    name      = "default-tls-cert"
    namespace = "kube-system"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.wildcard_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.wildcard_private_key
  }
}

resource "null_resource" "install-gateway-crds" {
  triggers = {
    gateway_api_version = var.gateway_api_version
  }

  provisioner "local-exec" {
    command = <<EOF
      KUBECONFIG=${data.terraform_remote_state.servers.outputs.kube_config} kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml
    EOF
  }

  depends_on = [kubernetes_secret_v1.default_tls_cert]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = templatefile("${path.module}/manifests/gateway.yaml.tftpl",
    {
      gateway_port = local.gateway_port
    }
  )

  depends_on = [null_resource.install-gateway-crds]
}

resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  values = [
    file("${path.module}/helm-values/cilium.yaml")
  ]

  set = [
    {
      name  = "k8sServiceHost"
      value = data.terraform_remote_state.network.outputs.aws_lb_internal_dns_name
    }
  ]

  depends_on = [kubectl_manifest.gateway]
}

# the default values of both rook charts, taken from the same tag as the charts
data "http" "rook_ceph_values" {
  for_each = toset(["rook-ceph", "rook-ceph-cluster"])
  url      = "https://raw.githubusercontent.com/rook/rook/refs/tags/v${var.rook_version}/deploy/charts/${each.key}/values.yaml"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "cannot download ${self.url} (HTTP ${self.status_code}), check rook_version."
    }
  }
}

locals {
  # the default cpu and memory requests are too high for our small cluster, so
  # we blank all of them
  rook_ceph_values = {
    for chart, response in data.http.rook_ceph_values :
    chart => replace(replace(response.response_body, "/cpu:.*/", "cpu:"), "/memory:.*/", "memory:")
  }
}

resource "helm_release" "rook-ceph-operator" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  version          = var.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    local.rook_ceph_values["rook-ceph"]
  ]

  depends_on = [helm_release.cilium]
}

resource "helm_release" "rook-ceph-cluster" {
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  version          = var.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    local.rook_ceph_values["rook-ceph-cluster"]
  ]

  set = [
    {
      name  = "toolbox.enabled"
      value = "true"
    }
  ]

  depends_on = [helm_release.rook-ceph-operator]
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    file("${path.module}/helm-values/argocd.yaml")
  ]

  set = [
    {
      name  = "global.domain"
      value = "argocd.${var.my_domain}"
    },
    {
      name  = "server.httproute.hostnames[0]"
      value = "argocd.${var.my_domain}"
    }
  ]

  depends_on = [helm_release.rook-ceph-cluster]
}

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    file("${path.module}/helm-values/argocd-apps.yaml")
  ]

  depends_on = [helm_release.argo_cd]
}
