output "kubernetes_master_ip" {
  value       = aws_instance.kubernetes_master.private_ip
  description = "kubernetes master private ip"
}
