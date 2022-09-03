output "kubernetes_server_ip" {
  description = "Kubernetes Server Public IP"
  value       = aws_eip.kubernetes_server.public_ip
}

output "kubernetes_node01_ip" {
  description = "Kubernetes Node01 Public IP"
  value       = aws_eip.kubernetes_node01.public_ip
}

output "kubernetes_node02_ip" {
  description = "Kubernetes Node02 Public IP"
  value       = aws_eip.kubernetes_node02.public_ip
}
