################################################################################
# firewall_rule_iap.tf.tpl
#
# Terraform template for deploying VPC firewall rules using:
# Google Cloud Foundation Fabric module: net-vpc-firewall v55.4.0
#
# Purpose:
#   - Disable Fabric's default firewall rules.
#   - Allow SSH to the DB VM only through Identity-Aware Proxy (IAP).
#   - Keep the VM private; do not allow direct public SSH.
#
# How to use:
#   1. Keep this file as a reference, or copy it to terraform/firewall.tf.
#   2. Make sure your DB VM has the network tag var.db_vm_network_tag.
#   3. Keep IAP IAM permissions separate in iam.tf.
#
# Important:
#   This firewall rule only allows the network path for IAP SSH.
#   Users still need IAM permissions such as roles/iap.tunnelResourceAccessor
#   and appropriate Compute/OS Login permissions.
################################################################################

################################################################################
# OPTIONAL VARIABLES
#
# These are here for clarity if you split this template out into its own file.
# If these variables already exist in variables.tf, do not duplicate them.
################################################################################

# variable "project_id" {
#   type        = string
#   description = "GCP project ID."
# }
#
# variable "vpc_name" {
#   type        = string
#   description = "VPC network name."
# }
#
# variable "db_vm_network_tag" {
#   type        = string
#   description = "Network tag attached to the DB VM. Firewall rules target this tag."
# }

################################################################################
# FIREWALL MODULE
################################################################################

module "db_vm_firewall" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc-firewall?ref=v55.4.0"

  # GCP project where the firewall rule will be created.
  project_id = var.project_id

  # VPC network where the firewall rule applies.
  #
  # Your current code uses var.vpc_name.
  # That is fine if the VPC is in the same project and the module accepts the name.
  #
  # Alternative, if you want to tie it directly to the VPC module output:
  # network = module.vpc.name
  network = var.vpc_name

  ##############################################################################
  # default_rules_config
  #
  # Fabric can create predefined firewall rules for common cases.
  #
  # disabled = true:
  #   Do not create Fabric's default convenience rules.
  #   Only create the explicit rules defined below.
  ##############################################################################
  default_rules_config = {
    disabled = true
  }

  ##############################################################################
  # ingress_rules
  #
  # Ingress means traffic entering the VPC/VM.
  #
  # This map creates one firewall rule:
  #   allow-iap-ssh-to-db-vm
  #
  # The rule allows SSH only from Google's IAP TCP forwarding range.
  ##############################################################################
  ingress_rules = {
    allow-iap-ssh-to-db-vm = {
      # Human-readable description shown in GCP.
      description = "Allow SSH to database VM only through IAP"

      # IAP TCP forwarding source range.
      #
      # This is not your laptop's IP address.
      # When you use:
      #   gcloud compute ssh --tunnel-through-iap
      # traffic reaches the VM from this Google-managed IAP range.
      source_ranges = ["35.235.240.0/20"]

      # Target only VMs with this network tag.
      #
      # Your DB VM must include:
      #   tags = [var.db_vm_network_tag]
      #
      # Labels are not the same as network tags.
      targets = [var.db_vm_network_tag]

      # Allowed protocol and port.
      #
      # tcp/22 = SSH.
      rules = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }

    ##########################################################################
    # OPTIONAL FUTURE RULE: POSTGRES FROM VPN / PEER CIDRS
    #
    # Uncomment and adapt this only after the VPN/peer CIDRs are agreed.
    #
    # Do NOT use source_ranges = ["0.0.0.0/0"] for Postgres.
    #
    # allow-postgres-from-vpn = {
    #   description   = "Allow Postgres from approved VPN peer ranges"
    #   source_ranges = var.vpn_peer_source_ranges
    #   targets       = [var.db_vm_network_tag]
    #
    #   rules = [
    #     {
    #       protocol = "tcp"
    #       ports    = ["5432"]
    #     }
    #   ]
    # }
    ##########################################################################
  }
}

################################################################################
# OPTIONAL VARIABLE FOR FUTURE POSTGRES/VPN FIREWALL RULE
#
# Uncomment only if you enable the allow-postgres-from-vpn rule above.
################################################################################

# variable "vpn_peer_source_ranges" {
#   type        = list(string)
#   description = "Approved peer CIDR ranges allowed to reach Postgres over VPN."
#   default     = []
# }

################################################################################
# NOTES
#
# IAP SSH path:
#
#   your laptop / gcloud
#       -> Identity-Aware Proxy
#       -> source range 35.235.240.0/20
#       -> tcp/22 on VM with var.db_vm_network_tag
#
# VPN/Postgres path later:
#
#   peer VPC/client CIDR
#       -> HA VPN tunnel
#       -> your VPC
#       -> firewall allows tcp/5432 only from approved peer CIDRs
#       -> DB VM with var.db_vm_network_tag
################################################################################
