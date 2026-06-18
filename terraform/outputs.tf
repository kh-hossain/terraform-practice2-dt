# Network outputs

output "vpc_self_link" {
  description = "VPC network self link"
  value       = module.vpc.self_link
}

output "management_subnet_self_link" {
  description = "Management subnet self link"
  value       = module.vpc.subnet_self_links[local.management_subnet_key]
}

# Database VM outputs

output "db_vm_sa_iam_email" {
    description = "Auto-created service account's email for the database VM"
  value = module.db_vm.service_account_iam_email
}