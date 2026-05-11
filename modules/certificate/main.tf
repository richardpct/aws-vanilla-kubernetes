resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.my_email
}

resource "acme_certificate" "wildcard" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.${var.my_domain}"

  recursive_nameservers        = ["8.8.8.8:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"
  }
}
