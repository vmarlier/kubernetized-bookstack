# =============================================================================
# Variables - Globals
# =============================================================================

variable "prod_project_id" { type = string }
variable "dev_project_id" { type = string }
variable "region" { type = string }
variable "domain" { type = string }
### ENV variables ###
# SCW access key to give the permission to bookstack to use an OS bucket
variable "scw_bucket_access_key" {}
variable "scw_bucket_secret_key" {}
# SMTP variables
variable "smtp_address" {}
variable "smtp_port" {}
variable "smtp_username" {}
variable "smtp_password" {}
