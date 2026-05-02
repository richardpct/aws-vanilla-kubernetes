output "kubernetes_api_internal" {
  value       = aws_lb.api_internal.dns_name
  description = "Kubernetes api internal"
}

output "use_cilium" {
  value       = var.use_cilium
  description = "If use Cilium or Calico CNI"
}

output "use_rook" {
  value       = var.use_rook
  description = "If use Rook Ceph or Longhorn CSI"
}
