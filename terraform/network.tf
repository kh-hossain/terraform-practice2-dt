module "vpc" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc?ref=v55.4.0"
  project_id = var.project_id
  name       = var.vpc_name
  subnets = [
    {
      ip_cidr_range         = var.db_subnet_cidr
      name                  = var.db_subnet_name
      region                = var.region
      enable_private_access = true

      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata             = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}
# tftest modules=1 resources=6 inventory=simple.yaml e2e

module "vpn_ha" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpn-ha?ref=v55.4.0"
  project_id = var.project_id
  region     = var.region
  network    = module.vpc.self_link
  name       = "${local.name_prefix}-db-to-backend-vpn-ha"

  router_config = {
    asn = 64514
  }
}

module "cloud_nat" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-cloudnat?ref=v55.4.0"

  project_id     = var.project_id
  region         = var.region
  name           = "${local.name_prefix}-nat"
  router_network = module.vpc.self_link

  router_create = true
  router_name   = "${local.name_prefix}-nat-router"

  config_source_subnetworks = {
    all = false

    subnetworks = [
      {
        self_link     = module.vpc.subnet_self_links["${var.region}/${var.db_subnet_name}"]
        all_ranges    = false
        primary_range = true
      }
    ]
  }
}
