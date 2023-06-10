# Install R-version 4.3.0 as image
FROM rocker/r-ver:4.3.0

# Install required ubuntu libraries for 'mlr'
RUN apt-get update -qq && apt-get install -y \
  libgdal-dev libgeos-dev libproj-dev r-cran-udunits2 libgsl-dev libgmp-dev libglu-dev  r-cran-rjags libmpfr-dev libopenmpi-dev

# Install required libraries
RUN R -e "install.packages('bigrquery')"
RUN R -e "install.packages('bigQueryR')"
RUN R -e "install.packages('DBI')"
RUN R -e "install.packages('lubridate')"
RUN R -e "install.packages('dotenv')"
RUN R -e "install.packages('RSocrata')"
RUN R -e "install.packages('beakr')"

# Expose the used port from beakr
EXPOSE 8080

# Add script
ADD . /app

# Set current working directory to the directory where the Model & App live.
WORKDIR /app

# Run the R script that contains the application
CMD ["Rscript", "./etl.R"]