output "kubernetes_api_internal" {
  value       = aws_lb.api_internal.dns_name
  description = "kubernetes api internal"
}

output "use_cilium" {
  value       = var.use_cilium
  description = "if use cilium or calico cni"
}

output "use_rook" {
  value       = var.use_rook
  description = "if use rook ceph or longhorn csi"
}

output "rook_version" {
  value       = var.rook_version
  description = "rook version"
}
