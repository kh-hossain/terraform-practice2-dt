# Network outputs

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.self_link
}

output "db_subnet_self_link" {
  description = "Database subnet self link"
  value       = module.vpc.subnet_self_links[local.db_subnet_key]
}

# Database VM outputs
