module "vpc" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc?ref=v55.4.0"
  project_id = var.project_id
  name       = var.vpc_name
  subnets = [
    {
      ip_cidr_range         = var.management_subnet_cidr
      name                  = var.management_subnet_name
      region                = var.region
      enable_private_access = true

      secondary_ip_ranges = {
        pods     = { ip_cidr_range = "172.16.0.0/20" }
        services = { ip_cidr_range = "192.168.0.0/24" }
      }

      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata             = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}
# tftest modules=1 resources=6 inventory=simple.yaml e2e

module "db_vm_firewall" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc-firewall?ref=v55.4.0"

  project_id = var.project_id
  network    = var.vpc_name

  default_rules_config = {
    disabled = true
  }

  ingress_rules = {
    allow-iap-ssh-to-db-vm = {
      description   = "Allow SSH to database VM only through IAP"
      source_ranges = ["35.235.240.0/20"]
      targets       = [var.db_vm_network_tag]

      rules = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  }
}