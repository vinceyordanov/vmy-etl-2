library(bigrquery)
library(bigQueryR)
library(DBI)
source("constants.R")


# -- Authenticating R to BigQuery for both BQ SDK's -- # 

bqr_auth(json_file = json, token = key)   #BigQueryR
bq_auth(path = json)                      #bigrquery



# -- Establish connection to BigQuery -- # 

con <- dbConnect(
  bigrquery::bigquery(),
  project = projectId,
  dataset = datasetId,
  billing = projectId
)

