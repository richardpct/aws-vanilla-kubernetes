terraform {
  backend "s3" {
  }
}

data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

data "terraform_remote_state" "servers" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_servers
    region = var.region
  }
}
