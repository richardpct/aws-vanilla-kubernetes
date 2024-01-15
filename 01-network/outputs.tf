output "vpc_id" {
  value       = aws_vpc.my_vpc.id
  description = "VPC ID"
}

output "subnet_public_id" {
  value       = aws_subnet.public.id
  description = "Subnet public ID"
}

output "subnet_private_worker" {
  value       = aws_subnet.private_worker[*].id
  description = "Subnet private worker"
}

output "subnet_public_lb" {
  value       = aws_subnet.public_lb[*].id
  description = "Subnet public lb"
}

output "aws_eip_nat_ip" {
  value       = aws_eip.nat[*].public_ip
  description = "eip IPs"
}
