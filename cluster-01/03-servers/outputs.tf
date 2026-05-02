output "kubernetes_api_internal" {
  value       = module.servers.kubernetes_api_internal
  description = "kubernetes api internal"
}

output "use_cilium" {
  value       = module.servers.use_cilium
  description = "use cilium or calico cni"
}

output "use_rook" {
  value       = module.servers.use_rook
  description = "use rook ceph or longhorn csi"
}
