################################################################################
# vpn.tf.tpl
#
# Terraform template for deploying YOUR side of a GCP HA VPN using:
# Google Cloud Foundation Fabric module: net-vpn-ha v55.4.0
#
# How to use:
#   1. Keep this file as a reference, or copy it to terraform/vpn.tf.
#   2. Fill the peer_* values from your colleague's handoff values.
#   3. Do not use terraform_remote_state or cross-project data sources unless
#      your team explicitly wants that coupling.
#
# Important:
#   - You do NOT need to set peer_gateways = {} or tunnels = {}.
#     Fabric already defaults both to empty maps.
#   - If you omit peer_gateways and tunnels, Terraform creates only:
#       * HA VPN gateway
#       * Cloud Router
#     It does NOT create a working VPN connection.
#   - For a working VPN connection, keep peer_gateways and tunnels in Terraform.
################################################################################

################################################################################
# INPUT VARIABLES FOR PEER HANDOFF
################################################################################

variable "local_router_asn" {
  type        = number
  description = "BGP ASN for this project's Cloud Router."
  default     = 64514
}

variable "peer_ha_vpn_gateway_self_link" {
  type        = string
  description = "Self link of the peer GCP HA VPN gateway."
}

variable "peer_router_asn" {
  type        = number
  description = "BGP ASN of the peer Cloud Router."
  default     = 64513
}

variable "tunnel_0_local_bgp_range" {
  type        = string
  description = "This side's BGP /30 range for tunnel 0."
  default     = "169.254.1.2/30"
}

variable "tunnel_0_peer_bgp_ip" {
  type        = string
  description = "Peer side's BGP IP address for tunnel 0."
  default     = "169.254.1.1"
}

variable "tunnel_1_local_bgp_range" {
  type        = string
  description = "This side's BGP /30 range for tunnel 1."
  default     = "169.254.2.2/30"
}

variable "tunnel_1_peer_bgp_ip" {
  type        = string
  description = "Peer side's BGP IP address for tunnel 1."
  default     = "169.254.2.1"
}

# Optional shared secrets.
# Keep these null if you want Fabric to generate secrets.
# Do NOT commit real shared secrets to Git.
variable "vpn_tunnel_0_shared_secret" {
  type        = string
  description = "Optional pre-shared key for tunnel 0."
  sensitive   = true
  default     = null
}

variable "vpn_tunnel_1_shared_secret" {
  type        = string
  description = "Optional pre-shared key for tunnel 1."
  sensitive   = true
  default     = null
}

################################################################################
# ROUTE ADVERTISEMENT LOCALS
################################################################################

locals {
  # Prefer advertising only what the peer actually needs.
  # For your project, this should usually be the management subnet CIDR.
  vpn_advertised_ip_ranges = {
    (var.management_subnet_cidr) = "management-subnet"
  }

  # Avoid advertising huge ranges like 10.0.0.0/8 unless your network team
  # explicitly approves that design.
}

################################################################################
# HA VPN MODULE
################################################################################

module "vpn_ha" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpn-ha?ref=v55.4.0"

  # GCP project where your side of the HA VPN gateway is created.
  project_id = var.project_id

  # Region for the HA VPN gateway and Cloud Router.
  region = var.region

  # VPC network where the HA VPN gateway is attached.
  # Your current repo has module "vpc", so this uses module.vpc.self_link.
  network = module.vpc.self_link

  # Name of your HA VPN gateway.
  name = "${local.name_prefix}-db-to-backend-vpn-ha"

  ##############################################################################
  # peer_gateways
  #
  # Defines the OTHER side of the VPN.
  #
  # default:
  #   A local key/name used by this module.
  #
  # gcp:
  #   Means the peer is another GCP HA VPN gateway.
  #
  # var.peer_ha_vpn_gateway_self_link:
  #   The self link your colleague gives you.
  #
  # Do not use module.vpn-2.self_link unless both VPN modules are in the same
  # Terraform root module and state.
  ##############################################################################
  peer_gateways = {
    default = {
      gcp = var.peer_ha_vpn_gateway_self_link
    }
  }

  ##############################################################################
  # router_config
  #
  # Creates/configures Cloud Router for BGP.
  #
  # HA VPN gateway:
  #   Terminates encrypted IPsec tunnels.
  #
  # Cloud Router:
  #   Exchanges routes over BGP so both sides know which CIDRs are reachable.
  ##############################################################################
  router_config = {
    # Your side's BGP ASN.
    # Must be coordinated with the peer and should be different from peer_router_asn.
    asn = var.local_router_asn

    # Optional custom route advertisement.
    #
    # all_subnets = false:
    #   Do not automatically advertise every subnet.
    #
    # ip_ranges:
    #   Explicitly advertise only selected ranges.

    # With custom_advertise:
    #   You explicitly control which routes your Cloud Router advertises to the peer.

    # Without custom_advertise:
    #   Cloud Router automatically advertises eligible subnet routes from your VPC.

    custom_advertise = {
      all_subnets = false
      ip_ranges   = local.vpn_advertised_ip_ranges
      # ip_ranges   = (var.management_subnet_cidr) = "management-subnet"
    }
  }

  ##############################################################################
  # tunnels
  #
  # Creates the actual VPN tunnels and BGP sessions.
  #
  # For HA VPN, use two tunnels:
  #   remote-0 -> HA VPN gateway interface 0
  #   remote-1 -> HA VPN gateway interface 1
  #
  # Your BGP IPs and your colleague's BGP IPs must mirror each other.

  # The Fabric variable comments say each BGP session on the same Cloud Router must use a unique /30 CIDR from 169.254.0.0/16

  # Fabric uses each tunnels entry to create a VPN tunnel, a Cloud Router interface, and a Cloud Router BGP peer.
  ##############################################################################
  tunnels = {
    remote-0 = {
      # Peer BGP settings for tunnel 0.
      bgp_peer = {
        address = var.tunnel_0_peer_bgp_ip
        asn     = var.peer_router_asn
      }

      # This side's BGP /30 range for tunnel 0.
      #
      # Example:
      #   peer side: 169.254.1.1
      #   your side: 169.254.1.2/30
      bgp_session_range = var.tunnel_0_local_bgp_range

      # Use HA VPN gateway interface 0.
      vpn_gateway_interface = 0

      # Optional pre-shared key.
      # If null, Fabric can generate it.
      shared_secret = var.vpn_tunnel_0_shared_secret
    }

    remote-1 = {
      # Peer BGP settings for tunnel 1.
      bgp_peer = {
        address = var.tunnel_1_peer_bgp_ip
        asn     = var.peer_router_asn
      }

      # This side's BGP /30 range for tunnel 1.
      #
      # Example:
      #   peer side: 169.254.2.1
      #   your side: 169.254.2.2/30
      bgp_session_range = var.tunnel_1_local_bgp_range

      # Use HA VPN gateway interface 1.
      vpn_gateway_interface = 1

      # Optional pre-shared key.
      # If null, Fabric can generate it.
      shared_secret = var.vpn_tunnel_1_shared_secret
    }
  }
}

################################################################################
# OUTPUTS TO HAND BACK TO YOUR COLLEAGUE
################################################################################

output "vpn_ha_gateway_self_link" {
  description = "Self link of this project's HA VPN gateway."
  value       = module.vpn_ha.self_link
}

output "vpn_ha_router_name" {
  description = "Cloud Router name created or used by the HA VPN module."
  value       = module.vpn_ha.router_name
}

output "vpn_ha_tunnel_names" {
  description = "VPN tunnel names created by the module."
  value       = module.vpn_ha.tunnel_names
}

output "vpn_ha_shared_secrets" {
  description = "Shared secrets for VPN tunnels if generated or managed by this module."
  value       = module.vpn_ha.shared_secrets
  sensitive   = true
}

################################################################################
# EXAMPLE terraform.tfvars VALUES
#
# peer_ha_vpn_gateway_self_link = "https://www.googleapis.com/compute/v1/projects/PEER_PROJECT/regions/us-central1/vpnGateways/PEER_GATEWAY_NAME"
# local_router_asn              = 64514
# peer_router_asn               = 64513
#
# tunnel_0_local_bgp_range = "169.254.1.2/30"
# tunnel_0_peer_bgp_ip     = "169.254.1.1"
#
# tunnel_1_local_bgp_range = "169.254.2.2/30"
# tunnel_1_peer_bgp_ip     = "169.254.2.1"
#
# Do not commit real shared secrets to Git:
# vpn_tunnel_0_shared_secret = "..."
# vpn_tunnel_1_shared_secret = "..."
################################################################################
