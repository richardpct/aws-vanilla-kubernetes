output "kube_config" {
  value       = module.servers.kube_config
  description = "kube config path"
}
