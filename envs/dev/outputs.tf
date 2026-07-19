output "external_alb_dns" {
  description = "Public DNS name to access the application"
  value       = module.load_balancers.external_alb_dns
}
