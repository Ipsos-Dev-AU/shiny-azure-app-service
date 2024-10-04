FROM rocker/r-ver:4.2.0

# Install system dependencies for ODBC
RUN apt-get update && apt-get install -y \
    unixodbc \
    unixodbc-dev \
    && apt-get clean

# Set renv version
ENV RENV_VERSION=v1.0.2

# Install R packages
RUN R -e "install.packages('remotes')"
RUN R -e "remotes::install_github('rstudio/renv@${RENV_VERSION}')"
RUN R -e "options(renv.config.repos.override = 'https://packagemanager.posit.co/cran/latest')"

# Copy the application code into the Docker image
COPY . /app

# Set the working directory
WORKDIR /app

# Restore the R environment with renv
RUN R -e "renv::restore()"

# Expose the port Shiny will run on
EXPOSE 3838

# Run the Shiny app
CMD ["R", "-e", "shiny::runApp('./app.R', host='0.0.0.0', port=3838)"]
