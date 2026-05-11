output "wildcard_private_key" {
  value     = module.certificate.wildcard_private_key
  sensitive = true
}

output "wildcard_certificate" {
  value = module.certificate.wildcard_certificate
}
