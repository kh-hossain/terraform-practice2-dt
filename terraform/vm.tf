module "db_vm" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/compute-vm?ref=v55.4.0"

  project_id = var.project_id
  zone       = var.default_zone
  name       = var.db_vm_name

  machine_type = "e2-micro"

  boot_disk = {
    initialize_params = {
      size = 10
      type = "pd-standard"
    }

    source = {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interfaces = [
    {
      network    = module.vpc.self_link
      subnetwork = module.vpc.subnet_self_links["${var.region}/${var.db_subnet_name}"]
    }
  ]

  tags = [var.db_vm_network_tag]

  metadata = {
    enable-oslogin = "TRUE"
    #startup-script = file("${path.module}/startup.sh")
  }

  service_account = {
    auto_create = true
  }

  shielded_config = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}