module "bucket" {
  source      = "../../modules/bucket"
  aws_profile = var.aws_profile
  region      = var.region
  bucket      = var.bucket
}
