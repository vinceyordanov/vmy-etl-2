library(dotenv)
readRenviron(".Renviron")

# -- GCP project credentials and environment variables -- #

projectId = Sys.getenv("PROJECT_ID")
datasetId = 'chicago'
key = Sys.getenv("GCP_KEY")
json = Sys.getenv("JSON_KEY")
app_token = Sys.getenv("SOCRATA_TOKEN")
email = Sys.getenv("EMAIL_ADDRESS")
password = Sys.getenv("PASSWORD")



