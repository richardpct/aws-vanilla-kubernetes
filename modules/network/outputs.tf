output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "subnet_public" {
  value = aws_subnet.public[*].id
}

output "subnet_private" {
  value = aws_subnet.private[*].id
}

output "subnet_private_efs" {
  value = aws_subnet.private_efs[*].id
}

output "aws_lb_external_dns_name" {
  value = aws_lb.external.dns_name
}

output "aws_lb_internal_dns_name" {
  value = aws_lb.internal.dns_name
}

output "aws_lb_target_group_external_api_arn" {
  value = aws_lb_target_group.external_api.arn
}

output "aws_lb_target_group_internal_api_arn" {
  value = aws_lb_target_group.internal_api.arn
}

output "aws_lb_target_group_external_https_arn" {
  value = aws_lb_target_group.external_https.arn
}

output "aws_iam_instance_profile_name" {
  value = aws_iam_instance_profile.profile.name
}

output "aws_security_group_efs_id" {
  value = aws_security_group.efs.id
}

output "aws_security_group_bastion_id" {
  value = aws_security_group.bastion.id
}

output "aws_security_group_kubernetes_master_id" {
  value = aws_security_group.kubernetes_master.id
}

output "aws_security_group_kubernetes_worker_id" {
  value = aws_security_group.kubernetes_worker.id
}

output "aws_eip_bastion_id" {
  value = aws_eip.bastion.id
}

output "aws_eip_bastion_ip" {
  value = aws_eip.bastion.public_ip
}

output "aws_eip_nat_ip" {
  value = aws_eip.nat[*].public_ip
}
