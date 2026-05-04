output "kubernetes_api_internal" {
  value       = aws_lb.api_internal.dns_name
  description = "kubernetes api internal"
}

output "rook_version" {
  value       = var.rook_version
  description = "rook version"
}
