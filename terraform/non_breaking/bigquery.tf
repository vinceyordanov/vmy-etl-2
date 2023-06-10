# -- Create BigQuery table in which run & pipeline cutoff dates will be logged -- #

resource "google_bigquery_table" "run_log" {
  dataset_id          = var.dataset_id
  description         = "This table is used to look up the most recent cutoff dates for previous pipeline executions"
  table_id            = "run_log"
  schema              = file("${path.module}/../../schemas/run_log.json")
  deletion_protection = false
}


# -- Create BigQuery daily-partitioned table which will contain cleaned Chicago ShotSpotter & Homicide data -- #

resource "google_bigquery_table" "shotspotter_clean" {
  dataset_id          = var.dataset_id
  description         = "This table contains cleaned ShotSpotter event data from Chicago, joined with Chicago homicide data."
  table_id            = var.table_id
  schema              = file("${path.module}/../../schemas/shotspotter_clean.json")

  time_partitioning {
    type       = "DAY"
    field      = "event_date"
  }

  deletion_protection = false
}


# -- Create a service account IAM member for BQ data transfer jobs -- # 

data "google_project" "project" {
}

# -- Enable IAM Service API -- # 
resource "google_project_service" "iam_googleapis_com" {
  project = var.project_id
  service = "iam.googleapis.com"
}

# -- Enable BQ data transfer service API -- # 

resource "google_project_service" "bigquerydatatransfer_googleapis_com" {
  project = var.project_id
  service = "bigquerydatatransfer.googleapis.com"
}


resource "google_project_iam_member" "permissions" {
  depends_on = [google_project_service.bigquerydatatransfer_googleapis_com]
  project    = data.google_project.project.project_id
  role       = "roles/iam.serviceAccountTokenCreator"
  member     = "serviceAccount:scheduler-sa@r-server-326920.iam.gserviceaccount.com"
}


# -- Create scheduled query to execute the shotspotter_clean.sql module every Sunday at 23:30 CEST -- #

resource "google_bigquery_data_transfer_config" "shotspotter_clean_query" {
  depends_on                = [google_project_iam_member.permissions]
  display_name              = "shotspotter-clean-query"
  location                  = "US"
  project                   = var.project_id
  data_source_id            = "scheduled_query"
  schedule                  = "every 15 mins"
  #schedule                  = "every sunday 04:30"
  params = {
    query                   = "${file("${path.module}/../../queries/shotspotter_clean.sql")}"
  }

}