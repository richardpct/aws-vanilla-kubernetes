output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_private" {
  value = module.network.subnet_private
}

output "subnet_public" {
  value = module.network.subnet_public
}

output "aws_eip_nat_ip" {
  value = module.network.aws_eip_nat_ip
}
