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

variable "management_subnet_name" {
  type        = string
  description = "Name of the management subnet"
}

variable "management_subnet_cidr" {
  type        = string
  description = "CIDR range for the management subnet"
}