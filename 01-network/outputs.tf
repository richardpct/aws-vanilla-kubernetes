output "vpc_id" {
  value       = aws_vpc.my_vpc.id
  description = "VPC ID"
}

output "subnet_public_id" {
  value       = aws_subnet.public.id
  description = "Subnet public ID"
}

output "subnet_private_node_a" {
  value       = aws_subnet.private_node_a.id
  description = "Subnet private node a"
}

output "subnet_private_node_b" {
  value       = aws_subnet.private_node_b.id
  description = "Subnet private node b"
}
