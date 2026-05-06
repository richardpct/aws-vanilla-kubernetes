output "rook_version" {
  value       = module.servers.rook_version
  description = "rook version"
}

output "kube_config" {
  value       = module.servers.kube_config
  description = "kube config path"
}
