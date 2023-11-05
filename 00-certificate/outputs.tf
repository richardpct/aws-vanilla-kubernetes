output "grafana_private_key" {
  value       = acme_certificate.grafana_certificate.private_key_pem
  description = "Grafana private key"
  sensitive   = true
}

output "grafana_certificate" {
  value       = acme_certificate.grafana_certificate.certificate_pem
  description = "Grafana certificate"
}
