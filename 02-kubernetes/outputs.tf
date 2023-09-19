output "kubernetes_master_ip" {
  description = "Kubernetes master public IP"
  value       = aws_eip.kubernetes_master.public_ip
}

output "lb_web" {
  description = "DNS of the LB"
  value       = aws_lb.web.dns_name
}
