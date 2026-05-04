module "servers" {
  source                      = "../../modules/servers"
  aws_profile                 = var.aws_profile
  region                      = var.region
  env                         = "cluster-01"
  network_remote_state_bucket = var.bucket
  network_remote_state_key    = var.key_network
  my_domain                   = var.my_domain
  my_ip_address               = var.my_ip_address
  ssh_public_key              = var.ssh_public_key
  use_cilium                  = true
  use_rook                    = true
  rook_version                = "1.19.5"
  record_dns                  = ["argocd", "grafana"]
}
