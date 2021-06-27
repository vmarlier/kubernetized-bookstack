terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "2.0.0-rc1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.0.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.0.0"
    }
  }
  required_version = "~> 0.14"
}
