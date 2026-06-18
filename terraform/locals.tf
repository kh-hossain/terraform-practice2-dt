locals {
  name_prefix = "${var.activity_name}-${var.environment}"
}

locals {
  common_labels = {
    managed_by  = "terraform"
    environment = replace(lower(var.environment), ".", "-")
    repo        = replace(lower(var.git_repo_name), ".", "-")
    activity    = replace(lower(var.activity_name), ".", "-")
    owner       = replace(lower(var.owner), ".", "-")
  }
}

# Network configuration locals

locals {
  management_subnet_key = "${var.region}/${var.management_subnet_name}"
}