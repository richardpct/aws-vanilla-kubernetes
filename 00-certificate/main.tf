terraform {
  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
  }
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.my_email
}

resource "acme_certificate" "grafana_certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "grafana.${var.my_domain}"

  dns_challenge {
    provider = "route53"
  }
}

resource "acme_certificate" "vault_certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "vault.${var.my_domain}"

  dns_challenge {
    provider = "route53"
  }
}

resource "acme_certificate" "www2_certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "www2.${var.my_domain}"

  dns_challenge {
    provider = "route53"
  }
}
