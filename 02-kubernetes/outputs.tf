output "kubernetes_server_ip" {
  description = "Kubernetes server public IP"
  value       = aws_eip.kubernetes_server.public_ip
}

//output "kubernetes_node01_ip" {
//  description = "Kubernetes node01 private IP"
//  value       = aws_instance.kubernetes_node01.private_ip
//}
//
//output "kubernetes_node02_ip" {
//  description = "Kubernetes node02 private IP"
//  value       = aws_instance.kubernetes_node02.private_ip
//}
