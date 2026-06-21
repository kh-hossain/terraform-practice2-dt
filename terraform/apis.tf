locals {
  project_services = toset([
    "compute.googleapis.com",
    "networkconnectivity.googleapis.com",
    "backupdr.googleapis.com",
  ])
}

resource "google_project_service" "project_services" {
  for_each = local.project_services

  project = var.project_id
  service = each.value

  # Prevent terraform destroy from disabling APIs that may be shared
  # by other resources or teams.
  disable_on_destroy = false
}