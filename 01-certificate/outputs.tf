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
