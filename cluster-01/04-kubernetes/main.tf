module "kubernetes" {
  source                          = "../../modules/kubernetes"
  aws_profile                     = var.aws_profile
  region                          = var.region
  env                             = "cluster-01"
  certificate_remote_state_bucket = var.bucket
  certificate_remote_state_key    = var.key_certificate
  servers_remote_state_bucket     = var.bucket
  servers_remote_state_key        = var.key_servers
}
