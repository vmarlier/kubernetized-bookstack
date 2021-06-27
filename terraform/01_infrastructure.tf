# =============================================================================
# Scaleway - Project
# =============================================================================

# No API available yet for datasource project from ID
locals {
  project_id = terraform.workspace == "production" ? var.prod_project_id : var.dev_project_id
  region     = var.region
  common_tags = [
    "environment=${terraform.workspace}",
    "platform=example",
    "service=bookstack"
  ]
}

# =============================================================================
# Scaleway - Bookstack - Object Storage Buckets
# =============================================================================

resource "random_id" "bucket" {
  byte_length = 2
  prefix      = "fr-par-oss-bookstack-uploads-"
}

resource "scaleway_object_bucket" "upload_bucket" {
  name   = random_id.bucket.hex
  acl    = "private"
  region = local.region
}


# =============================================================================
# Scaleway - Bookstack - MYSQL Storage
# =============================================================================

resource "scaleway_rdb_instance" "bookstack_mysql" {
  name           = "fr-par-rdb-bookstack-mysql"
  node_type      = "db-dev-s"
  engine         = "MySQL-8"
  is_ha_cluster  = true
  disable_backup = false
  region         = local.region
  tags           = local.common_tags
  project_id     = local.project_id

  # lifecycle { prevent_destroy = true }
}

resource "random_password" "bookstack_rdb_password" {
  length      = 32
  special     = true
  lower       = true
  number      = true
  upper       = true
  min_lower   = 10
  min_upper   = 10
  min_numeric = 6
  min_special = 6
}

resource "scaleway_rdb_user" "bookstack_user" {
  instance_id = scaleway_rdb_instance.bookstack_mysql.id
  name        = "bookstack"
  password    = random_password.bookstack_rdb_password.result
  is_admin    = false

  # Destroy database when destroy the user
  provisioner "local-exec" {
    when    = destroy
    command = "scw rdb database delete region=fr-par instance-id=${split("/", self.instance_id)[1]} name=${self.name}"
  }

  # Create database
  provisioner "local-exec" {
    command = "scw rdb database create region=fr-par instance-id=${split("/", self.instance_id)[1]} name=${self.name}"
  }

  # Grant privilege access to the user
  provisioner "local-exec" {
    command = <<-EOF
    scw rdb privilege set region=fr-par \
    instance-id=${split("/", self.instance_id)[1]} \
    database-name=${self.name} \
    user-name=${self.name} \
    permission=all \
    && sleep 5
    EOF
  }
}

# =============================================================================
# Wait services confirmation to move to application setup
# =============================================================================

resource "time_sleep" "wait_build_infra" {
  depends_on      = [scaleway_rdb_user.bookstack_user]
  create_duration = "15s"
}
