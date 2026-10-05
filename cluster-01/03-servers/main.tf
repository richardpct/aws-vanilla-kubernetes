module "servers" {
  source                      = "../../modules/servers"
  aws_profile                 = var.aws_profile
  region                      = var.region
  env                         = "cluster-01"
  network_remote_state_bucket = var.bucket
  network_remote_state_key    = var.key_network
  ssh_public_key              = var.ssh_public_key
  kube_config                 = "~/.kube/config-aws"
}
