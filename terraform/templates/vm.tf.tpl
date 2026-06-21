################################################################################
# vm.tf.tpl
#
# Terraform template for deploying a database/management VM using:
# Google Cloud Foundation Fabric module: compute-vm v55.4.0
#
# Purpose:
#   - Create a small Ubuntu VM in the management subnet.
#   - Attach the VM to the VPC/subnet created by the net-vpc module.
#   - Allow IAP SSH through a network tag targeted by firewall rules.
#   - Auto-create a dedicated VM service account.
#   - Enable Shielded VM security features.
#
# How to use:
#   1. Keep this file as a reference, or copy it to terraform/vm.tf.
#   2. Prefer using module.vpc outputs for network/subnetwork instead of passing
#      vpc_self_link and management_subnet_self_link as root input variables.
#   3. Make sure the firewall rule targets var.db_vm_network_tag.
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
# variable "default_zone" {
#   type        = string
#   description = "Zone where the DB VM will be created."
# }
#
# variable "region" {
#   type        = string
#   description = "Region where the management subnet exists."
# }
#
# variable "db_vm_name" {
#   type        = string
#   description = "Name of the DB VM."
# }
#
# variable "db_vm_network_tag" {
#   type        = string
#   description = "Network tag attached to the DB VM for firewall targeting."
# }
#
# variable "management_subnet_name" {
#   type        = string
#   description = "Name of the management subnet."
# }

################################################################################
# OPTIONAL LOCALS
#
# Labels are GCP resource labels for filtering, billing, and inventory.
# They are NOT used by VPC firewall rules.
#
# Network tags are used by firewall rules.
################################################################################

locals {
  db_vm_labels = {
    component = "database"
    role      = "postgres"
  }
}

################################################################################
# DB VM MODULE
################################################################################

module "db_vm" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/compute-vm?ref=v55.4.0"

  # GCP project where the VM will be created.
  project_id = var.project_id

  # Zone where the VM will be created.
  # Example: us-central1-a
  zone = var.default_zone

  # VM instance name.
  name = var.db_vm_name

  # Small machine type suitable for a lab/practice DB VM.
  # For production workloads, size this based on DB memory/CPU/storage needs.
  machine_type = "e2-micro"

  ##############################################################################
  # boot_disk
  #
  # Defines the VM boot disk and OS image.
  ##############################################################################
  boot_disk = {
    initialize_params = {
      # Boot disk size in GB.
      size = 10

      # pd-standard = standard persistent disk.
      # For better DB performance, consider pd-balanced or pd-ssd.
      type = "pd-standard"
    }

    source = {
      # Ubuntu 24.04 LTS image from the public Ubuntu image project.
      image = "ubuntu-os-cloud/ubuntu-2404-lts"
    }
  }

  ##############################################################################
  # network_interfaces
  #
  # Attaches the VM to the VPC and management subnet.
  #
  # Preferred:
  #   network    = module.vpc.self_link
  #   subnetwork = module.vpc.subnet_self_links["${var.region}/${var.management_subnet_name}"]
  #
  # Avoid using var.vpc_self_link and var.management_subnet_self_link unless this
  # VM module is intentionally separated from the VPC module and those values are
  # passed in from a parent module.
  ##############################################################################
  network_interfaces = [
    {
      network = module.vpc.self_link

      subnetwork = module.vpc.subnet_self_links["${var.region}/${var.management_subnet_name}"]

      # nat = true gives the VM an external IP/NAT config.
      #
      # For a more private design, consider nat = false and use:
      #   - IAP for SSH
      #   - Private Google Access for Google APIs
      #   - Cloud NAT if the VM needs outbound internet package downloads
      nat = true
    }
  ]

  ##############################################################################
  # tags
  #
  # Network tags are used by firewall rules.
  #
  # Your firewall module targets this value:
  #   targets = [var.db_vm_network_tag]
  ##############################################################################
  tags = [
    var.db_vm_network_tag
  ]

  ##############################################################################
  # labels
  #
  # Labels are for organization, billing, filtering, and inventory.
  # They are not firewall targets.
  ##############################################################################
  labels = local.db_vm_labels

  ##############################################################################
  # metadata
  #
  # enable-oslogin = TRUE:
  #   Enables OS Login, so SSH access is controlled with IAM instead of manually
  #   managing SSH keys on the VM.
  #
  # startup-script:
  #   Optional. You can use a startup script, but for your current approach you
  #   are planning a separate Bash bootstrap script that SSHs through IAP.
  ##############################################################################
  metadata = {
    enable-oslogin = "TRUE"

    # Optional:
    # startup-script = file("${path.module}/startup.sh")
  }

  ##############################################################################
  # service_account
  #
  # auto_create = true:
  #   Fabric creates a dedicated service account for this VM and attaches it.
  #
  # To grant this VM access to Secret Manager, bind:
  #   roles/secretmanager.secretAccessor
  #
  # to:
  #   module.db_vm.service_account_iam_email
  #
  # Prefer granting access on the specific secret, not the whole project.
  ##############################################################################
  service_account = {
    auto_create = true
  }

  ##############################################################################
  # shielded_config
  #
  # Enables Shielded VM security features.
  ##############################################################################
  shielded_config = {

    # Before the OS starts, verify the bootloader/kernel path has not been tampered with.
    enable_secure_boot          = true

    # Record trusted measurements of the VM boot process.
    enable_vtpm                 = true

    # Integrity monitoring checks the VM’s boot measurements against a known-good baseline.
    enable_integrity_monitoring = true
  }
}

################################################################################
# OUTPUTS
#
# Useful for scripts and IAM bindings.
################################################################################

output "db_vm_name" {
  description = "Name of the DB VM."
  value       = var.db_vm_name
}

output "db_vm_zone" {
  description = "Zone of the DB VM."
  value       = var.default_zone
}

output "db_vm_service_account_email" {
  description = "Email address of the VM service account."
  value       = module.db_vm.service_account_email
}

output "db_vm_service_account_iam_email" {
  description = "IAM member string for the VM service account."
  value       = module.db_vm.service_account_iam_email
}

################################################################################
# NOTES
#
# IAP SSH:
#   - Firewall must allow tcp/22 from 35.235.240.0/20.
#   - User/group must have IAP tunnel and OS Login permissions.
#
# Postgres container:
#   - Can be installed by a separate bootstrap script using:
#       gcloud compute ssh --tunnel-through-iap
#
# Secrets:
#   - Prefer Secret Manager for DB password.
#   - Grant secret accessor to module.db_vm.service_account_iam_email.
#
# Private networking:
#   - If you set nat = false, make sure the VM can still install packages.
#   - Common options:
#       * Cloud NAT
#       * private apt mirror
#       * bake Docker into a custom image
################################################################################
