################################################################################
# vpc.tf.tpl
#
# Terraform template for deploying a GCP VPC and management subnet using:
# Google Cloud Foundation Fabric module: net-vpc v55.4.0
#
# How to use:
#   1. Keep this file as a reference, or copy it to terraform/network.tf.
#   2. Fill project_id, vpc_name, region, management_subnet_name, and
#      management_subnet_cidr through variables or terraform.tfvars.
#   3. Adjust or remove secondary_ip_ranges if you are not using GKE/pods/services.
#   4. Adjust flow_logs_config based on cost/visibility requirements.
################################################################################

################################################################################
# OPTIONAL VARIABLES FOR SECONDARY RANGES
#
# Your original snippet hardcoded:
#   pods     = 172.16.0.0/20
#   services = 192.168.0.0/24
#
# These variables make those ranges easier to change without editing module code.
################################################################################

variable "pods_secondary_range_cidr" {
  type        = string
  description = "Secondary IP range for GKE pods or future container workloads."
  default     = "172.16.0.0/20"
}

variable "services_secondary_range_cidr" {
  type        = string
  description = "Secondary IP range for GKE services or future container workloads."
  default     = "192.168.0.0/24"
}

################################################################################
# VPC MODULE
################################################################################

module "vpc" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc?ref=v55.4.0"

  # GCP project where the VPC will be created.
  project_id = var.project_id

  # VPC network name.
  name = var.vpc_name

  ##############################################################################
  # subnets
  #
  # List of subnets to create inside the VPC.
  #
  # This project currently creates one subnet:
  #   - management_subnet
  #
  # The DB/management VM should be placed inside this subnet.
  ##############################################################################
  subnets = [
    {
      # Primary CIDR range of the subnet.
      # Example: 10.10.0.0/24
      ip_cidr_range = var.management_subnet_cidr

      # Subnet name.
      name = var.management_subnet_name

      # Region where the subnet exists.
      # Subnets are regional resources in GCP.
      region = var.region

      # Enables Private Google Access.
      #
      # This allows VMs without external IPs to reach supported Google APIs
      # through internal/private connectivity.
      enable_private_access = true

      ##########################################################################
      # secondary_ip_ranges
      #
      # Optional secondary ranges.
      #
      # These are commonly used for GKE:
      #   pods     -> Pod IP range
      #   services -> Kubernetes Service IP range
      #
      # If this subnet will only host a VM/Postgres container and no GKE cluster,
      # you can remove this entire block.
      ##########################################################################
      secondary_ip_ranges = {
        pods = {
          ip_cidr_range = var.pods_secondary_range_cidr
        }

        services = {
          ip_cidr_range = var.services_secondary_range_cidr
        }
      }

      ##########################################################################
      # flow_logs_config
      #
      # Enables and configures VPC Flow Logs for this subnet.
      #
      # Useful for:
      #   - troubleshooting network traffic
      #   - verifying VPN/client access
      #   - security visibility
      #
      # Tradeoff:
      #   - more logging can increase Cloud Logging costs
      ##########################################################################
      flow_logs_config = {
        # How often logs are aggregated.
        aggregation_interval = "INTERVAL_5_SEC"

        # Sampling rate between 0.0 and 1.0.
        # 0.5 means roughly 50% sampling.
        flow_sampling = 0.5

        # Include metadata such as VM/project/subnet info.
        metadata = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}

################################################################################
# OPTIONAL OUTPUTS
#
# Keep these if other modules/scripts need to consume the VPC/subnet self links.
################################################################################

output "vpc_self_link" {
  description = "Self link of the VPC network."
  value       = module.vpc.self_link
}

output "management_subnet_self_link" {
  description = "Self link of the management subnet."
  value       = module.vpc.subnet_self_links["${var.region}/${var.management_subnet_name}"]
}

################################################################################
# EXAMPLE terraform.tfvars VALUES
#
# project_id             = "my-gcp-project"
# region                 = "us-central1"
# vpc_name               = "db-vpc"
# management_subnet_name = "management-subnet"
# management_subnet_cidr = "10.10.0.0/24"
#
# pods_secondary_range_cidr     = "172.16.0.0/20"
# services_secondary_range_cidr = "192.168.0.0/24"
################################################################################
