# ----- Define properly formatted variable names to be used as image address ----- #

locals {
  artifact_storage_address = "${var.region}-docker.pkg.dev/${var.project_id}/${var.registry_id}/pipeline"
  tag                      = "1.0.0"
}


# -- Create an instance of the file we're monitoring for changes to trigger docker build -- # 

resource "local_file" "etl" {
  content = templatefile("${path.module}/../../src/changelog.txt", {})
  filename = "${path.module}/../../src/changelog.txt"
}


# ----- Custom action used to call docker build on updates of tf configuration. ----- # 

resource "null_resource" "docker_build" {
    triggers = {
        file_changed = md5(local_file.etl.content)
    }
    provisioner "local-exec" {
        working_dir = path.module
        command     = "cd ../../src && docker build -t ${local.artifact_storage_address}:${local.tag} . && docker push ${local.artifact_storage_address}:${local.tag}"
    }
    depends_on = [local_file.etl]
}



# ----- Create GCP cloud run service on which to deploy our containerized ETL pipeline & API ----- # 

resource "google_cloud_run_service" "default" {
    name     = "containerized-pipeline"
    location = var.region
    project  = var.project_id
    template {
      spec {
        containers {
          image = "${local.artifact_storage_address}:${local.tag}"
          ports {
            name           = "http1"
            container_port = 8080
          }
          resources {
            limits = {
              "cpu"    = "1000m"
              "memory" = "2000Mi"
            }
          }
        }
        timeout_seconds = 300
        container_concurrency = 80
      }
      metadata {
        annotations = {
          "run.googleapis.com/client-name"      = "terraform"
          #"run.googleapis.com/cpu-throttling"   = false
          #"autoscaling.knative.dev/minScale"    = 1
          #"autoscaling.knative.dev/maxScale"    = 30
        }
      }
    }
    traffic {
        percent         = 100
        latest_revision = true
    }
    depends_on = [
        null_resource.docker_build
    ]
 }



# ----- Cloud run invoker ----- # 

data "google_iam_policy" "noauth" {
   binding {
     role = "roles/run.invoker"
     members = ["allUsers"]
   }
 }

 resource "google_cloud_run_service_iam_policy" "noauth" {
   location    = google_cloud_run_service.default.location
   project     = google_cloud_run_service.default.project
   service     = google_cloud_run_service.default.name
   policy_data = data.google_iam_policy.noauth.policy_data
}
