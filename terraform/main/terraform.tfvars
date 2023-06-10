project_id                              = "r-server-326920"
region                                  = "europe-west4"
zone                                    = "europe-west4"
service_account                         = "terraform@r-server-326920.iam.gserviceaccount.com"
registry_id                             = "deploy-pipeline"
dataset_id                              = "chicago_raw"
table_id                                = "shotspotter"
scheduler_sa_roles                      = ["roles/cloudscheduler.admin", "roles/run.invoker"]