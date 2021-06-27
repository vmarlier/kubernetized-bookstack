terraform {
  backend "s3" {
    bucket                      = "fr-par-p-oss-tfstate-do-not-delete"
    key                         = "bookstack/application-bookstack.tfstate"
    region                      = "fr-par"
    endpoint                    = "https://s3.fr-par.scw.cloud"
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}
