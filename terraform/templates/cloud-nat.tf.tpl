################################################################################
# cloud-nat.tf.tpl
#
# Terraform template for deploying Cloud NAT using:
# Google Cloud Foundation Fabric module: net-cloudnat v55.4.0
#
# Purpose:
#   - Keep the DB VM private with no public IP.
#   - Allow outbound internet access from the management subnet.
#   - Reuse the Cloud Router created by the HA VPN module.
#
# Network model:
#
#   Inbound SSH:
#     laptop -> IAP -> private VM tcp/22
#
#   Outbound internet:
#     private VM -> Cloud NAT -> internet
#
#   Inbound DB traffic later:
#     peer network -> HA VPN -> firewall tcp/5432 -> private VM
#
# Important:
#   Cloud NAT is outbound-only for your VM. It does not expose the VM publicly.
################################################################################

################################################################################
# OPTIONAL VARIABLES
#
# These are here for clarity if you split this template into its own file.
# If these variables already exist in variables.tf, do not duplicate them.
################################################################################

# variable "project_id" {
#   type        = string
#   description = "GCP project ID."
# }
#
# variable "region" {
#   type        = string
#   description = "Region for Cloud NAT and Cloud Router."
# }
#
# variable "management_subnet_name" {
#   type        = string
#   description = "Name of the management subnet."
# }

################################################################################
# CLOUD NAT MODULE
################################################################################

module "cloud_nat" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-cloudnat?ref=v55.4.0"

  # GCP project where Cloud NAT is created.
  project_id = var.project_id

  # Region for Cloud NAT.
  #
  # Cloud NAT is regional and must be in the same region as the Cloud Router.
  region = var.region

  # Cloud NAT gateway name.
  name = "${local.name_prefix}-nat"

  # VPC network associated with the Cloud Router / Cloud NAT.
  router_network = module.vpc.self_link

  ##############################################################################
  # router_create / router_name
  #
  # router_create = false:
  #   Do not create a new Cloud Router.
  #
  # router_name:
  #   Reuse the Cloud Router created by the HA VPN module.
  #
  # This avoids having two separate routers in the same region/VPC when one router
  # can support both:
  #   - HA VPN BGP sessions
  #   - Cloud NAT control plane
  #
  ##############################################################################
  router_create = false
  router_name   = module.vpn-ha.router_name

  ##############################################################################
  # config_source_subnetworks
  #
  # Controls which subnetworks/ranges use Cloud NAT.
  #
  # all = false:
  #   Do not NAT every subnet automatically.
  #
  # subnetworks:
  #   Explicitly list the subnetworks that should use Cloud NAT.
  #
  # This template enables NAT only for the management subnet primary range.
  ##############################################################################
  config_source_subnetworks = {
    all = false

    subnetworks = [
      {
        # The net-vpc module exposes subnet self links as a map keyed by:
        #   "<region>/<subnet_name>"
        self_link = module.vpc.subnet_self_links["${var.region}/${var.management_subnet_name}"]

        # all_ranges = false:
        #   Do not NAT all primary + secondary ranges.
        all_ranges = false

        # primary_range = true:
        #   NAT the subnet's primary IP range.
        #
        # This is enough for a VM whose NIC is in the primary subnet range.
        primary_range = true

        # If you later need NAT for secondary ranges, add them explicitly,
        # depending on the module's supported schema/version.
      }
    ]
  }
}

################################################################################
# OPTIONAL OUTPUTS
################################################################################

output "cloud_nat_name" {
  description = "Name of the Cloud NAT gateway."
  value       = module.cloud_nat.name
}

output "cloud_nat_router_name" {
  description = "Cloud Router used by Cloud NAT."
  value       = module.cloud_nat.router_name
}

################################################################################
# REQUIRED VM SETTING
#
# In your compute-vm module, set:
#
# network_interfaces = [
#   {
#     network    = module.vpc.self_link
#     subnetwork = module.vpc.subnet_self_links["${var.region}/${var.management_subnet_name}"]
#     nat        = false
#   }
# ]
#
# nat = false:
#   The VM gets no public IP.
#
# Cloud NAT:
#   Gives the private VM outbound internet access without exposing inbound access.
################################################################################
