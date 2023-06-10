terraform {
  required_version = ">=0.13"
  backend "gcs" {
    bucket = "r-server-326920-tf-states-main-1"
  }
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.1"
    }
  }
}

# -- Specifies GCP Project which Terraform will manage -- # 

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}



# -- Specifies the service account that terraform will use to manage infrastructure -- #
locals {
  tf_sa = var.service_account
}