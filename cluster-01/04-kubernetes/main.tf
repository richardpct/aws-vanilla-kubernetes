module "kubernetes" {
  source                          = "../../modules/kubernetes"
  aws_profile                     = var.aws_profile
  region                          = var.region
  env                             = "cluster-01"
  my_domain                       = var.my_domain
  certificate_remote_state_bucket = var.bucket
  certificate_remote_state_key    = var.key_certificate
  network_remote_state_bucket     = var.bucket
  network_remote_state_key        = var.key_network
  servers_remote_state_bucket     = var.bucket
  servers_remote_state_key        = var.key_servers
  rook_version                    = "1.20.8"
  gateway_api_version             = "v1.6.1"
}
