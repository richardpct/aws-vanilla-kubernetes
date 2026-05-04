output "kubernetes_api_internal" {
  value       = module.servers.kubernetes_api_internal
  description = "kubernetes api internal"
}

output "rook_version" {
  value       = module.servers.rook_version
  description = "rook version"
}
