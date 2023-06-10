resource "google_bigquery_dataset" "dataset" {
  project                     = var.project_id
  dataset_id                  = var.dataset_id
  friendly_name               = var.dataset_id
  description                 = "Dataset containing raw Chicago ShotSpotter data"
  location                    = "US"
}

resource "google_bigquery_table" "raw" {
  depends_on   = [google_bigquery_dataset.dataset]
  dataset_id   = var.dataset_id
  table_id     = var.table_id
  description  = "This table contains the raw shotspotter data from the city of Chicago."

  time_partitioning {
    type       = "DAY"
    field      = "event_date"
  }

  schema       = file("${path.module}/../../schemas/shotspotter.json")

  
}