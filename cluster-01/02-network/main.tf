module "network" {
  source             = "../../modules/network"
  aws_profile        = var.aws_profile
  region             = var.region
  env                = "cluster-01"
  my_domain          = var.my_domain
  my_ip_address      = var.my_ip_address
  vpc_cidr_block     = "10.0.0.0/16"
  subnet_private     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_private_efs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  subnet_public      = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
  record_dns         = ["argocd", "grafana"]
}
