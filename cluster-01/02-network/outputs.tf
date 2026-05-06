output "vpc_id" {
  value = module.network.vpc_id
}

output "subnet_private" {
  value = module.network.subnet_private
}

output "subnet_private_efs" {
  value = module.network.subnet_private_efs
}

output "subnet_public" {
  value = module.network.subnet_public
}

output "aws_lb_external_dns_name" {
  value = module.network.aws_lb_external_dns_name
}

output "aws_lb_api_internal_dns_name" {
  value = module.network.aws_lb_api_internal_dns_name
}

output "aws_lb_target_group_api_arn" {
  value = module.network.aws_lb_target_group_api_arn
}

output "aws_lb_target_group_api_internal_arn" {
  value = module.network.aws_lb_target_group_api_internal_arn
}

output "aws_lb_target_group_https_arn" {
  value = module.network.aws_lb_target_group_https_arn
}

output "aws_iam_instance_profile_name" {
  value = module.network.aws_iam_instance_profile_name
}

output "aws_security_group_efs_id" {
  value = module.network.aws_security_group_efs_id
}

output "aws_security_group_bastion_id" {
  value = module.network.aws_security_group_bastion_id
}

output "aws_security_group_kubernetes_master_id" {
  value = module.network.aws_security_group_kubernetes_master_id
}

output "aws_security_group_kubernetes_worker_id" {
  value = module.network.aws_security_group_kubernetes_worker_id
}

output "aws_eip_bastion_id" {
  value = module.network.aws_eip_bastion_id
}

output "aws_eip_bastion_ip" {
  value = module.network.aws_eip_bastion_ip
}

output "aws_eip_nat_ip" {
  value = module.network.aws_eip_nat_ip
}
