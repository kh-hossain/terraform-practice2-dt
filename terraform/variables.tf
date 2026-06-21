# Variables for GCP project and backend configuration

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "default_zone" {
  type        = string
  description = "Default GCP zone"
  default     = "us-central1-c"
}

variable "terraform_service_account" {
  type        = string
  description = "Service account used by Terraform through impersonation"
  sensitive   = true
}

# Variables for consistent tagging across resources

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
}

variable "git_repo_name" {
  type        = string
  description = "Name of the Git repository for tagging purposes"
}

variable "activity_name" {
  type        = string
  description = "Name of the activity for tagging purposes"
}

# Variables for network configuration

variable "vpc_name" {
  type        = string
  description = "Name of the VPC network"
}

variable "db_subnet_name" {
  type        = string
  description = "Name of the database subnet"
}

variable "db_subnet_cidr" {
  type        = string
  description = "CIDR range for the database subnet"
}

# Variables for the database VM

variable "db_vm_name" {
  type        = string
  description = "Name of the database VM"
}

variable "db_vm_network_tag" {
  type        = string
  description = "Network tag for the database VM"
}

variable "iap_authorized_members" {
  type        = list(string)
  description = "IAM members allowed to SSH to the bastion through IAP"
  default     = [] # Makes the module more flexible - even if not set, it won't cause an error

  # Example:
  # ["user:your-email@example.com"]
}

# DR Applicance variables

variable "backup_dr_appliance_sa" {
  type        = string
  description = "Service account for the DR appliance"
  sensitive   = true
}

variable "ncc_spoke_admin_members" {
  type        = list(string)
  description = "IAM members for the NCC spoke admin role"
  default     = [] # Makes the module more flexible - even if not set, it won't cause an error
}