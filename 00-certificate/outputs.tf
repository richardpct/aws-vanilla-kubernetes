output "grafana_private_key" {
  value       = acme_certificate.grafana_certificate.private_key_pem
  description = "Grafana private key"
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

output "www2_certificate" {
  value       = acme_certificate.www2_certificate.certificate_pem
  description = "www2 certificate"
}
