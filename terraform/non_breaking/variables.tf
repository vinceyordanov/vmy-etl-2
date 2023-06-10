# -- Define the necessary variables to be used for creating our GCP resources -- ##

variable "project_id" {
  description = "Project ID"
  type        = string
}

variable "region" {
  description = "Default region for GCP resources"
  type        = string
}

variable "zone" {
  description = "Zone of the GCP project"
  type        = string
}

variable "service_account" {
  description = "Service account to impersonate"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery Dataset ID"
  type        = string
}

variable "table_id" {
  description = "Table ID for clean shotspotter BQ table"
  type        = string
}
