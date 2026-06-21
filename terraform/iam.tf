resource "google_project_iam_member" "os_login" {
  for_each = toset(var.iap_authorized_members)

  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = each.value
}

resource "google_iap_tunnel_instance_iam_member" "iap_tunnel_access" {
  for_each = toset(var.iap_authorized_members)

  project  = var.project_id
  zone     = var.default_zone
  instance = var.db_vm_name

  role   = "roles/iap.tunnelResourceAccessor"
  member = each.value

  depends_on = [module.db_vm]
}


# DR IAM and SA Blocks

resource "google_project_iam_member" "backup_dr_compute_engine_operator" {
  project = var.project_id
  role    = "roles/backupdr.computeEngineOperator"
  member  = var.backup_dr_appliance_sa
}

resource "google_project_iam_member" "ncc_network_permissions" {
  for_each = {
    for pair in setproduct(var.ncc_spoke_admin_members, local.ncc_network_roles) :
    "${pair[0]}-${pair[1]}" => {
      member = pair[0]
      role   = pair[1]
    }
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}