output "grafana_private_key" {
  value     = acme_certificate.grafana_certificate.private_key_pem
  sensitive = true
}

output "vault_private_key" {
  value     = acme_certificate.vault_certificate.private_key_pem
  sensitive = true
}

output "www2_private_key" {
  value     = acme_certificate.www2_certificate.private_key_pem
  sensitive = true
}

output "argocd_private_key" {
  value     = acme_certificate.argocd_certificate.private_key_pem
  sensitive = true
}

output "jfrog_private_key" {
  value     = acme_certificate.jfrog_certificate.private_key_pem
  sensitive = true
}

output "grafana_certificate" {
  value = acme_certificate.grafana_certificate.certificate_pem
}

output "vault_certificate" {
  value = acme_certificate.vault_certificate.certificate_pem
}

output "www2_certificate" {
  value = acme_certificate.www2_certificate.certificate_pem
}

output "argocd_certificate" {
  value = acme_certificate.argocd_certificate.certificate_pem
}

output "jfrog_certificate" {
  value = acme_certificate.jfrog_certificate.certificate_pem
}
