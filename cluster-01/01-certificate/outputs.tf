output "grafana_private_key" {
  value     = module.certificate.grafana_private_key
  sensitive = true
}

output "vault_private_key" {
  value     = module.certificate.vault_private_key
  sensitive = true
}

output "www2_private_key" {
  value     = module.certificate.www2_private_key
  sensitive = true
}

output "argocd_private_key" {
  value     = module.certificate.argocd_private_key
  sensitive = true
}

output "jfrog_private_key" {
  value     = module.certificate.jfrog_private_key
  sensitive = true
}

output "grafana_certificate" {
  value = module.certificate.grafana_certificate
}

output "vault_certificate" {
  value = module.certificate.vault_certificate
}

output "www2_certificate" {
  value = module.certificate.www2_certificate
}

output "argocd_certificate" {
  value = module.certificate.argocd_certificate
}

output "jfrog_certificate" {
  value = module.certificate.jfrog_certificate
}
