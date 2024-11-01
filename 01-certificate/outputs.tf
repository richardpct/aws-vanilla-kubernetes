output "grafana_private_key" {
  value       = acme_certificate.grafana_certificate.private_key_pem
  description = "Grafana private key"
  sensitive   = true
}

output "vault_private_key" {
  value       = acme_certificate.vault_certificate.private_key_pem
  description = "Vault private key"
  sensitive   = true
}

output "www2_private_key" {
  value       = acme_certificate.www2_certificate.private_key_pem
  description = "www2 private key"
  sensitive   = true
}

output "argocd_private_key" {
  value       = acme_certificate.argocd_certificate.private_key_pem
  description = "argocd private key"
  sensitive   = true
}

output "jfrog_private_key" {
  value       = acme_certificate.jfrog_certificate.private_key_pem
  description = "jfrog private key"
  sensitive   = true
}

output "grafana_certificate" {
  value       = acme_certificate.grafana_certificate.certificate_pem
  description = "Grafana certificate"
}

output "vault_certificate" {
  value       = acme_certificate.vault_certificate.certificate_pem
  description = "Vault certificate"
}

output "www2_certificate" {
  value       = acme_certificate.www2_certificate.certificate_pem
  description = "www2 certificate"
}

output "argocd_certificate" {
  value       = acme_certificate.argocd_certificate.certificate_pem
  description = "argocd certificate"
}

output "jfrog_certificate" {
  value       = acme_certificate.jfrog_certificate.certificate_pem
  description = "jfrog certificate"
}
