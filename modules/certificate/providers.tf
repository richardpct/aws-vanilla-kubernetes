provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
