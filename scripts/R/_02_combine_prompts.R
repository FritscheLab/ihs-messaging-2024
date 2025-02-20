# scripts/R/02_combine_prompts.R
# -----------------------------------------------------------
# This script combines prompt components into full system prompts based on
# various configurations (personalization, data context, framing, and approach).
# It generates:
#  - Full prompt files for each configuration.
#  - User request files.
#  - Command-line shell scripts to trigger the Python API call.
#
# Ensure that 00_setup.R has been run to set up the environment.
# -----------------------------------------------------------

library(data.table)

# Set a reproducible seed
set.seed(ceiling(pi * 1E6))

# Define global directories (assumed set by 00_setup.R)
base_dir <- getwd() # Repository root
data_dir <- file.path(base_dir, "data", "prompt_elements")
results_dir <- file.path(base_dir, "results")

# Utility function to read a text file from the prompt_elements directory
read_text_file <- function(filename) {
    path <- file.path(data_dir, filename)
    if (!file.exists(path)) stop("File not found: ", path)
    readLines(path)
}

# Read text files required for output
example_output <- list(
    with_datacontext = read_text_file("ExampleOutput_with_placeholder.txt"),
    no_datacontext   = read_text_file("ExampleOutput_without_placeholder.txt"),
    part1            = read_text_file("Prompt_part1.txt"),
    chain_of_thought = read_text_file("Chain_Of_Thought.txt"),
    part2            = read_text_file("Prompt_part2.txt"),
    personalization  = read_text_file("Personalization.txt")
)

# Define strategies and corresponding filenames
strategies <- c("BS", "CS", "DST", "MF", "MI")
strategy_files <- paste0("Approach_", strategies, ".txt")
names(strategy_files) <- c("Behavioral Strategies", "Cognitive Strategies", "Distanced Self-Talk", "Mindfulness", "Motivational Interviewing")

# Define metrics and corresponding names
metrics <- setNames(c("Mood", "Sleep", "Step"), c("Mood Score", "Hours of Sleep", "Step Count"))
functions <- setNames(c("Avg", "Min", "Max"), c("Average", "Minimum", "Maximum"))
time_intervals <- setNames(c("7Days", "30Days"), c("7 days", "30 days"))

# Define framing options and corresponding files
framing_options <- c("Practical", "Emotional", "Loss", "Gain")
framing_files <- paste0("Framing_", framing_options, ".txt")
frame <- setNames(framing_files, framing_options)

# Define personalization options and corresponding files
personalization_options <- c("Personalized", "Generic")
personalization_files <- paste0("Personalization_", personalization_options, ".txt")
personalization_list <- setNames(personalization_files, personalization_options)

# Create all combinations using CJ
combinations <- CJ(
    Metric   = unname(metrics),
    Function = unname(functions),
    Interval = unname(time_intervals),
    Framing  = framing_options
)

# Add a custom placeholder field for each combination
combinations[, CustomField := paste0("<%CustomField.Metric_", Metric, "_", Function, "_", Interval, "%>")]

# Map descriptive names for use in the user request
combinations[, MetricName := names(metrics)[match(Metric, metrics)]]
combinations[, FunctionName := names(functions)[match(Function, functions)]]
combinations[, IntervalName := names(time_intervals)[match(Interval, time_intervals)]]

# Read Data Context text
data_context_text <- read_text_file("DataContext.txt")

# Function to generate full prompt files, user requests, and command-line scripts
generate_prompts <- function(combinations, example_output, strategy_files, frame, data_context_text, results_dir) {
    cmd_lines <- vector("list")

    # Ensure the results directory exists
    if (!dir.exists(results_dir)) {
        dir.create(results_dir, recursive = TRUE)
    }

    # Iterate through configuration flags and approaches
    for (is_personalized in c(TRUE, FALSE)) {
        for (is_datacontext in c(TRUE, FALSE)) {
            for (approach_name in names(strategy_files)) {
                for (i in seq_len(nrow(combinations))) {
                    # Define a file prefix based on the current configuration
                    file_prefix <- sprintf(
                        "%s_%s_%s_%s_%s_%s_%03d",
                        combinations$Metric[i],
                        combinations$Function[i],
                        combinations$Interval[i],
                        ifelse(is_datacontext, "datacontext", "nodatacontext"),
                        ifelse(is_personalized, "personalized", "generic"),
                        gsub(" ", "", approach_name),
                        i
                    )

                    # Set the first part of the prompt based on the data context flag
                    part1_out <- if (is_datacontext) {
                        c(example_output$part1, "", data_context_text)
                    } else {
                        c(example_output$part1, "", "### Data Contextualization: None required")
                    }

                    # Load framing and approach texts
                    framing_text <- read_text_file(frame[approach_name])
                    approach_text <- read_text_file(strategy_files[approach_name])
                    # Choose the appropriate example output based on data context
                    example_output_text <- if (is_datacontext) example_output$with_datacontext else example_output$no_datacontext

                    # Build the full prompt by combining all parts
                    full_prompt <- c(
                        part1_out, "",
                        if (is_personalized) read_text_file(personalization_list[["Personalized"]]) else read_text_file(personalization_list[["Generic"]]),
                        "",
                        framing_text, "",
                        approach_text, "",
                        example_output$chain_of_thought, "",
                        example_output$part2,
                        example_output_text
                    )

                    # Write the full prompt to a file
                    prompt_file <- file.path(results_dir, paste0(file_prefix, "_prompt.txt"))
                    write(full_prompt, prompt_file, sep = "\n", append = FALSE)

                    # Write the user request file
                    user_request <- sprintf(
                        "Please generate four messages based on the following data:\nMetric: %s %s\nTime Interval: %s\nInclude Data: %s",
                        combinations$FunctionName[i], combinations$MetricName[i],
                        combinations$IntervalName[i], ifelse(is_datacontext, "Yes", "No")
                    )
                    user_request_file <- file.path(results_dir, paste0(file_prefix, "_user_request.txt"))
                    write(user_request, user_request_file, sep = "\n", append = TRUE)

                    # Create the command-line string to run the Python script.
                    # Notice the use of shQuote() to safely quote file paths that may contain spaces.
                    cmd_line <- sprintf(
                        "python %s --input_file %s --config_file config --system_prompt %s --output_dir results --output_prefix %s",
                        shQuote(file.path("scripts", "python", "ihs_messaging_prompt1.py")),
                        shQuote(sub("\\.txt$", "", user_request_file)),
                        shQuote(sub("\\.txt$", "", prompt_file)),
                        shQuote(file_prefix)
                    )

                    # Write an individual command-line shell script for this configuration
                    cmd_file <- file.path(results_dir, paste0(file_prefix, "_cmd_line.sh"))
                    write(cmd_line, cmd_file, sep = "\n", append = FALSE)
                    system(paste("chmod +x", shQuote(cmd_file)))

                    cmd_lines[[length(cmd_lines) + 1]] <- cmd_file
                }
            }
        }
    }

    # Write all command lines to a batch file for convenience
    batch_cmd_file <- file.path(results_dir, "cmd_lines.txt")
    write(unlist(cmd_lines), batch_cmd_file, sep = "\n", append = FALSE)
}

# Generate prompts and associated files
generate_prompts(combinations, example_output, strategy_files, frame, data_context_text, results_dir)

cat("Combined prompt generation complete. Please check the 'results' directory for output files.\n")
