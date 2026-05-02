output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "subnet_public" {
  value = aws_subnet.public[*].id
}

output "subnet_private" {
  value = aws_subnet.private[*].id
}

output "aws_eip_nat_ip" {
  value = aws_eip.nat[*].public_ip
}
