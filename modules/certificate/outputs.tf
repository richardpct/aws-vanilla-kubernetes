output "wildcard_private_key" {
  value       = acme_certificate.wildcard.private_key_pem
  description = "wildcard private key"
  sensitive   = true
}

output "wildcard_certificate" {
  value       = "${acme_certificate.wildcard.certificate_pem}${acme_certificate.wildcard.issuer_pem}"
  description = "wildcard certificate"
}
