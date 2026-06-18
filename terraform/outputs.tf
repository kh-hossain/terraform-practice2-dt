# Network outputs

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.self_link
}

output "management_subnet_self_link" {
  description = "Management subnet self link"
  value       = module.vpc.subnet_self_links[local.management_subnet_key]
}