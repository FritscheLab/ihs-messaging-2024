# scripts/R/00_setup.R
# -----------------------------------------------------------
# This script sets up the R environment for the IHS Intervention Messages project.
# It checks for, installs required packages and defines
# key directory paths for data and results.
# -----------------------------------------------------------

# List of required packages
required_packages <- c("data.table", "openxlsx")

# Function to install missing packages
install_if_missing <- function(packages) {
    installed <- rownames(installed.packages())
    for (pkg in packages) {
        if (!(pkg %in% installed)) {
            message(paste("Installing missing package:", pkg))
            install.packages(pkg, dependencies = TRUE)
        }
    }
}

# Install any missing packages
install_if_missing(required_packages)

# Load required libraries
lapply(required_packages, require, character.only = TRUE)

# Define global directories based on the repository structure
base_dir <- getwd() # Assuming the working directory is the repository root
data_dir <- file.path(base_dir, "data", "prompt_elements")
results_dir <- file.path(base_dir, "results")

# Create the results directory if it doesn't exist
if (!dir.exists(results_dir)) {
    dir.create(results_dir, recursive = TRUE)
    message("Created results directory: ", results_dir)
}

# Check if the data directory exists
if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE)
    message("Created data directory: ", data_dir)
}

# Print a summary of the setup
cat("Environment setup complete.\n")
cat("Base Directory:   ", base_dir, "\n")
cat("Data Directory:   ", data_dir, "\n")
cat("Results Directory:", results_dir, "\n")
