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