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

output "aws_eip_nat_ip" {
  value = aws_eip.nat[*].public_ip
}
