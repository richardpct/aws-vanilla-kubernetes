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
  provisioner "local-exec" {
    command = <<EOF
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
    EOF
  }

  depends_on = [kubernetes_secret_v1.default_tls_cert]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = templatefile("${path.module}/manifests/gateway.yaml.tftpl",
    {
      gateway_nodeport = "30443"
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
    "${file("${path.module}/helm-values/cilium.yaml")}"
  ]

  set = [
    {
      name  = "k8sServiceHost"
      value = data.terraform_remote_state.network.outputs.aws_lb_api_internal_dns_name
    }
  ]

  depends_on = [kubectl_manifest.gateway]
}

resource "helm_release" "rook-ceph-operator" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  version          = data.terraform_remote_state.servers.outputs.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-operator-values.yaml")}"
  ]

  depends_on = [helm_release.cilium]
}

resource "helm_release" "rook-ceph-cluster" {
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  version          = data.terraform_remote_state.servers.outputs.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-cluster-values.yaml")}"
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
    "${file("${path.module}/helm-values/argocd.yaml")}"
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
    "${file("${path.module}/helm-values/argocd-apps.yaml")}"
  ]

  depends_on = [helm_release.argo_cd]
}
