module "certificate" {
  source      = "../../modules/certificate"
  aws_profile = var.aws_profile
  region      = var.region
  env         = "cluster-01"
  my_domain   = var.my_domain
  my_email    = var.my_email
}
