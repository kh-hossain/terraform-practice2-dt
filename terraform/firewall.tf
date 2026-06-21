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

    allow-backup-dr-appliance-to-db-vm = {
      description = "Allow Backup and DR appliance traffic to DB VM"
      source_ranges = ["10.10.0.0/24"]
      targets = [local.db_vm_network_tag]

       rules = [
      {
        protocol = "tcp"
        ports = [
          "26",
          "443",
          "3260",
          "5106",
          "5107",
        ]
      }
    ]
  }
}