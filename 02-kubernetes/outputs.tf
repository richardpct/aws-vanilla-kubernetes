output "kubernetes_master_ip" {
  description = "Kubernetes master public IP"
  value       = aws_eip.kubernetes_master.public_ip
}
