output "vpc_id" {
  value       = aws_vpc.my_vpc.id
  description = "VPC ID"
}

output "subnet_public_id" {
  value       = aws_subnet.public.id
  description = "Subnet public ID"
}

output "subnet_private_node" {
  value       = aws_subnet.private_node[*].id
  description = "Subnet private node"
}

output "asg_lb_web_id" {
  value       = aws_security_group.lb_web.id
  description = "asg lb web id"
}

output "lb_target_group_http_arn" {
  value       = aws_lb_target_group.http.arn
  description = "lb target group http arn"
}

output "lb_target_group_https_arn" {
  value       = aws_lb_target_group.https.arn
  description = "lb target group http arn"
}

output "route53_zone_id" {
  value = data.aws_route53_zone.main.zone_id
}

#output "subnet_public_lb" {
#  value       = aws_subnet.public_lb[*].id
#  description = "Subnet public lb"
#}
