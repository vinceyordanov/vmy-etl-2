# -- Configure global R environment to avoid timeouts and errors -- # 
options(warn=-1)                                          # Do not return warning messages on verbose()
options(timeout = max(1000, getOption("timeout")))        # Increase timeout threshold when R establishes connections

# -- Load necessary libraries / SDKs -- #
library(lubridate)
library(RSocrata)
library(beakr)

# -- Import constants and auth scripts -- # 
source("constants.R")
source("auth.R")


# -- Query which obtains the most recent partition, used to determine incremental batch size OR initial run -- ##

q = '
     WITH cte AS (
      SELECT 
        COUNT(1) AS total_partitions,
        MAX(IF(partition_id ="__NULL__" OR partition_id IS NULL, NULL, PARSE_DATE("%Y%m%d",partition_id))) AS most_recent_partition,
      FROM `r-server-326920.chicago_raw.INFORMATION_SCHEMA.PARTITIONS`
      WHERE table_name = "shotspotter"
      AND partition_id != "__NULL__"
      AND partition_id IS NOT NULL
    )
    SELECT MAX(IF(total_partitions = 0, DATE("2017-01-01"),most_recent_partition))
    FROM cte
'


# -- Make API call to Socrata database and fetch recent shotspotter data -- # 

getData = function(date){
  require(RSocrata)
  date = date
  df = read.socrata(
    sprintf('https://data.cityofchicago.org/resource/3h7q-7mdb.json?$where=date>"%sT00:00:00.000"',date),
    app_token = app_token,
    email     = email,
    password  = password
  )
  return(df)
}


# -- Add a date field, re-order and remove unnecessary columns -- # 

cleanData = function(df){
  shots = df
  shots$event_date = as.Date(substr(shots$date, 1, 10))
  shots = shots[,c(1,22,2:21)]
  shots = shots[,-c(9,10,21,22)]
  return(shots)
}


# -- Restructure dataframe to have field types that are consistent with out BigQuery table schema -- # 

reformatData = function(data) {
  data = na.omit(data)
  colnames(data)[1] = "timestamp"
  data$timestamp = as.POSIXct(as_datetime(data$timestamp))
  data$event_date = as.Date(data$event_date)
  data$zip_code = as.integer(data$zip_code)
  data$ward = as.integer(data$ward)
  data$district = as.integer(data$district)
  data$month = as.integer(data$month)
  data$day_of_week = as.integer(data$day_of_week)
  data$hour = as.integer(data$hour)
  data$rounds = as.integer(data$rounds)
  data$illinois_house_district = as.integer(data$illinois_house_district)
  data$illinois_senate_district = as.integer(data$illinois_senate_district)
  data$latitude = as.double(data$latitude)
  data$longitude = as.double(data$longitude)
  data$server_timestamp = as.POSIXct(rep(Sys.time(), nrow(data)))
  return(data)
}


# -- Use BigQuery R client to insert initial set of shotspotter data into newly created BQ table -- # 

load2BQinitial = function(data) {
  require(bigQueryR)
  bqr_upload_data(
    projectId = "r-server-326920",
    datasetId = "chicago_raw", 
    tableId = "shotspotter", 
    upload_data = data,
    create = c("CREATE_IF_NEEDED"),
    schema = schema_fields(data), 
    sourceFormat = c("CSV"),
    writeDisposition = "WRITE_EMPTY",
    wait = TRUE, 
    nullMarker = "NA", 
    maxBadRecords = NULL, 
    allowJaggedRows = FALSE,
    allowQuotedNewlines = FALSE, 
    fieldDelimiter = ","
  )
}

# -- Use BigQuery R client to insert latest batch of shotspotter data into our BQ table -- # 

load2BQincremental = function(data) {
  require(bigQueryR)
  bqr_upload_data(
    projectId = "r-server-326920",
    datasetId = "chicago_raw", 
    tableId = "shotspotter", 
    upload_data = data,
    create = c("CREATE_IF_NEEDED"),
    sourceFormat = c("CSV"),
    writeDisposition = "WRITE_APPEND",
    wait = TRUE, 
    nullMarker = "NA", 
    maxBadRecords = NULL, 
    allowJaggedRows = FALSE,
    allowQuotedNewlines = FALSE, 
    fieldDelimiter = ","
  )
}



# -- Callback function which accepts GET Requests from Cloud Scheduler Invokation -- # 
# If the most recent partition date is Jan 1, 2017 we insert the initial amount of data
# Otherwise we insert the most recent batch

runPipeline = function(arg_1){
  body = as.character(arg_1)
  if (body == "run") {
    date = as.character(dbGetQuery(con, q)$`f0_`)
    if (date == "2017-01-01") {
      load2BQinitial(data = reformatData(data=cleanData(df=getData(date=date))))
    }
    if (date != "2017-01-01") {
      load2BQincremental(data = reformatData(data=cleanData(df=getData(date=date))))
    }
    return((paste0("Pipeline has successfully executed, most recent data inserted is from ", date)))
  }
  else {
    return((paste0("Something went wrong, please make sure GET request is sent correctly.")))
  }
}


# -- Start API server to listen for events in order to allow Cloud Scheduler to invoke container -- # 

newBeakr() %>% 
  httpGET(path = "/launch", decorate(runPipeline)) %>%        # Respond to GET requests at the "/launch" route
  handleErrors() %>%                                          # Handle any errors with a JSON response
  listen(host = "0.0.0.0", port = 8080)                       # Start the server on port 8080

