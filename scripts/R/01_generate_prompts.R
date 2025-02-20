# scripts/R/01_generate_prompts.R
# -----------------------------------------------------------
# This script generates the prompt components for the IHS Intervention Messages project.
# It loads text resources from the data/prompt_elements directory, creates combinations
# of options using data.table, and generates system prompt files and user request files.
#
# Ensure that the environment has been set up by running 00_setup.R before executing this script.
# -----------------------------------------------------------

library(data.table)

# Set a reproducible seed
set.seed(ceiling(pi * 1E6))

# Define global directories (these should be defined in 00_setup.R; otherwise, set here)
base_dir <- getwd() # Repository root
data_dir <- file.path(base_dir, "data", "prompt_elements")
results_dir <- file.path(base_dir, "results")

# Utility function to read text files with error handling
read_text_file <- function(filename) {
    path <- file.path(data_dir, filename)
    if (!file.exists(path)) {
        stop("File not found: ", path)
    }
    readLines(path)
}

# Load static text resources
part1 <- read_text_file("Prompt_part1.txt")
selfchecks <- read_text_file("Self_Checks.txt")
chain_of_thought <- read_text_file("Chain_Of_Thought.txt")
task_datacontext <- read_text_file("Prompt_part2_DataContext.txt")
task_nodatacontext <- read_text_file("Prompt_part2_NoDataContext.txt")
output_note <- read_text_file("Output_Note.txt")

# Define data tables for combinations
metrics <- data.table(
    Metric     = c("Mood", "Sleep", "Steps"),
    MetricName = c("Mood", "Hours of Sleep", "Step Count")
)
metric_functions <- data.table(
    Function     = c("Avg", "Min", "Max"),
    FunctionName = c("Average", "Minimum", "Maximum")
)
time_intervals <- data.table(
    Interval     = c("7Days", "30Days", "PhaseBegin"),
    IntervalName = c("7 days", "30 days", "Since start of internship")
)
approaches_options <- data.table(
    Approach     = c("BS", "CS", "DST", "MF", "MI"),
    ApproachName = c("Behavioral Strategies", "Cognitive Strategies", "Distanced Self-Talk", "Mindfulness", "Motivational Interviewing")
)
datacontext_options <- data.table(
    DataContext = c(TRUE, FALSE),
    DataContextName = c("datacontext", "nodatacontext"),
    DataContextExampleFile = c("ExampleOutput_with_placeholder.txt", "ExampleOutput_without_placeholder.txt")
)
question_options <- data.table(
    Question     = c("Yes", "No"),
    QuestionName = c("Yes", "No")
)

# Create all possible combinations
combinations <- CJ(
    Metric = metrics$Metric,
    Function = metric_functions$Function,
    Interval = time_intervals$Interval,
    DataContext = datacontext_options$DataContext,
    Approach = approaches_options$Approach,
    Question = question_options$Question
)
combinations[, CustomField := paste0("<%CustomField.Metric_", Metric, "_", Function, "_", Interval, "%>")]

# Merge to add descriptive names
combinations <- merge(combinations, metrics, by = "Metric")
combinations <- merge(combinations, metric_functions, by = "Function")
combinations <- merge(combinations, time_intervals, by = "Interval")
combinations <- merge(combinations, datacontext_options, by = "DataContext")
combinations <- merge(combinations, approaches_options, by = "Approach")
combinations <- merge(combinations, question_options, by = "Question")

# Filter out invalid combinations
combinations <- combinations[!(Approach == "DST" & DataContext == TRUE)]
combinations <- combinations[!(Question == "No" & Approach %in% c("DST", "MI"))]

# Read quantile information
quantiles <- fread(file.path(data_dir, "quantiles.txt"), colClasses = "character")

# Merge quantile info with combinations by MetricName, IntervalName, and FunctionName
combinations <- merge(combinations, quantiles, by = c("MetricName", "IntervalName", "FunctionName"))

# Function to generate prompts based on a specific combination
generate_prompt <- function(combination, part1, chain_of_thought, results_dir = results_dir) {
    # Load approach-specific text and example output
    approach_text <- read_text_file(paste0("Approach_", combination$Approach, ".txt"))
    example_output <- read_text_file(paste0("ExampleOutput_", combination$Approach, ".txt"))

    idea <- combination[, RemedyIdea]
    situation <- combination[, InternSituation]

    # Generate intern context and remedy idea text based on approach type
    if (combination$Approach %in% c("BS", "MI")) {
        suggestion <- c(
            "\n### Intern Context and Remedy Idea:",
            "Use the following intern situation as backdrop and suggestion:",
            paste0("**Situation:** ", situation),
            paste0("**Remedy Idea:** ", idea),
            "\n**Inclusion Criteria:**",
            "- **Compatibility with Messaging Approach:** Ensure this suggestion complements the specified 'Messaging Approach'. Adapt content as necessary to fit seamlessly with the overall strategy.",
            "- **Intern Backdrop:** Incorporate the provided situation as a general backdrop for interns. This approach enhances relatability and relevance. Do not assume the intern is experiencing the exact situation described."
        )
    } else {
        suggestion <- c(
            "\n### Intern Context:",
            "Use the following intern situation as backdrop:",
            paste0("**Situation:** ", situation),
            "\n**Inclusion Criteria:**",
            "- **Compatibility with Messaging Approach:** Ensure this topic complements the specified 'Messaging Approach'. Adapt content as necessary.",
            "- **Intern Backdrop:** Incorporate the provided situation as a general backdrop for interns. This approach enhances relatability and relevance. Do not assume the intern is experiencing the exact situation described."
        )
    }

    # Define message framing text based on the Question option
    if (combination$Question == "No") {
        question_text <- c(
            "\n#### Avoid Framing Messages as Questions:",
            "- **Instruction on Framing:** Ensure that messages are statements rather than questions for clarity and assertiveness.\n"
        )
    } else {
        question_text <- c(
            "\n#### Frame Messages as Questions:",
            "- **Question-Based Framing:** Each message should be framed as a question to encourage active reflection. Ensure questions are open-ended.\n"
        )
    }

    # Add data contextualization if required
    if (combination$DataContext) {
        data_context_text <- c(
            "\n### Data Contextualization:",
            paste0("- Use the placeholder '", combination$CustomField, "' in the Low, Medium, and High messages."),
            "- Use 'min' for 'Minimum', 'max' for 'Maximum', and 'avg' for 'Average'.",
            "- The placeholder will be replaced with the corresponding numeric value when the message is sent.",
            paste0("- Provide specific data context: Metric (", combination$FunctionName, " ", combination$MetricName, ") and Time Interval (", combination$IntervalName, "). Do not generalize.\n")
        )
        part2 <- task_datacontext
        user_message <- sprintf(
            "Please generate four messages based on the following data:\nStatistical Descriptor: %s\nMetric: %s\nTime Interval: %s\nMessaging Approach: %s\n\nPlease use the placeholder '%s' in the Low, Medium, and High messages.",
            combination$FunctionName, combination$MetricName, combination$IntervalName, combination$ApproachName, combination$CustomField
        )
    } else {
        data_context_text <- NULL
        part2 <- task_nodatacontext
        user_message <- sprintf(
            "Please generate four messages based on the following data:\nStatistical Descriptor: %s\nMetric: %s\nTime Interval: %s\nMessaging Approach: %s",
            combination$FunctionName, combination$MetricName, combination$IntervalName, combination$ApproachName
        )
    }

    # Define a file prefix for saving files
    file_prefix <- sprintf(
        "%s_%s_%s_%s_%s_%s_%s_%03d",
        formatC(combination$Index, flag = 0, width = 4),
        combination$Metric,
        combination$Function,
        combination$Interval,
        combination$DataContextName,
        gsub(" ", "", combination$ApproachName),
        combination$Question,
        1
    )

    # Write the user request file
    user_request_file <- file.path(results_dir, paste0(file_prefix, "_user_request.txt"))
    write(user_message, user_request_file, sep = "\n", append = FALSE)

    # Combine all parts of the prompt
    full_prompt <- c(part1, approach_text, suggestion, data_context_text, selfchecks, chain_of_thought, part2, question_text, example_output, output_note)

    # Write the full prompt file
    prompt_file <- file.path(results_dir, paste0(file_prefix, "_prompt.txt"))
    write(full_prompt, prompt_file, sep = "\n", append = FALSE)

    # Create command line string for the Python API call.
    # Using shQuote() ensures file paths with spaces are handled properly.
    cmd_line <- sprintf(
        "python %s --input_file %s --config_file .config.ini --system_prompt %s --output_dir results --output_prefix %s",
        shQuote(file.path("scripts", "python", "ihs_message_generation.py")),
        shQuote(user_request_file),
        shQuote(prompt_file),
        shQuote(file_prefix)
    )

    return(cmd_line)
}

# Generate specific combinations for Avg, Min, and Max functions
avg_combos <- combinations[Function == "Avg", ]
min_combos <- combinations[Function == "Min", ]
max_combos <- combinations[Function == "Max", ]

# Randomly drop 50% of the Min and Max combinations
min_combos <- min_combos[sample(seq_len(nrow(min_combos)), nrow(min_combos) %/% 2)]
max_combos <- max_combos[sample(seq_len(nrow(max_combos)), nrow(max_combos) %/% 2)]
combinations <- rbind(avg_combos, min_combos, max_combos)

# Assign intern situations for each metric
combinations[, InternSituation := ""]
for (metric in c("Mood", "Sleep", "Steps")) {
    n_metric <- combinations[Metric == metric, .N]
    situations_file <- paste0("Situations_", metric, ".txt")
    situations <- read_text_file(situations_file)
    situation_labels <- as.character(cut(seq_len(n_metric),
        breaks = length(situations),
        labels = situations, include.lowest = TRUE
    ))
    combinations[Metric == metric, InternSituation := sample(situation_labels)]
}

# Assign remedy ideas for BS and MI approaches
combinations[, RemedyIdea := ""]
for (metric in c("Mood", "Sleep", "Steps")) {
    n_metric <- combinations[Metric == metric & Approach %in% c("BS", "MI"), .N]
    ideas_file <- paste0("Ideas_", metric, ".txt")
    ideas <- read_text_file(ideas_file)
    idea_labels <- as.character(cut(seq_len(n_metric),
        breaks = length(ideas),
        labels = ideas, include.lowest = TRUE
    ))
    combinations[Metric == metric & Approach %in% c("BS", "MI"), RemedyIdea := sample(idea_labels)]
}

# (Optional) Print distribution tables for validation
combinations[, print(table(QuestionName) / .N)]
combinations[, print(table(Function) / .N)]
combinations[, print(table(Approach) / .N)]
combinations[, print(table(Metric) / .N)]
combinations[, print(table(Interval) / .N)]
combinations[, print(table(DataContext) / .N)]

# Ensure underrepresented approaches are balanced by duplicating entries if needed
n_max_approach <- max(combinations[, table(Approach)])
n_dst_approach <- combinations[Approach == "DST", .N]
n_mi_approach <- combinations[Approach == "MI", .N]

# For DST approach
if (n_dst_approach < n_max_approach) {
    combinations_dst <- combinations[Approach == "DST", ]
    extra_dst <- combinations_dst[sample(seq_len(nrow(combinations_dst)), n_max_approach - n_dst_approach, replace = TRUE)]
    extra_dst[, InternSituation := ""]
    for (metric in c("Mood", "Sleep", "Steps")) {
        n_metric <- extra_dst[Metric == metric, .N]
        situations_file <- paste0("Situations_", metric, ".txt")
        situations <- read_text_file(situations_file)
        situation_labels <- as.character(cut(seq_len(n_metric),
            breaks = length(situations),
            labels = situations, include.lowest = TRUE
        ))
        extra_dst[Metric == metric, InternSituation := sample(situation_labels)]
    }
    combinations <- rbind(combinations, extra_dst)
}

# For MI approach
if (n_mi_approach < n_max_approach) {
    combinations_mi <- combinations[Approach == "MI", ]
    extra_mi <- combinations_mi[sample(seq_len(nrow(combinations_mi)), n_max_approach - n_mi_approach, replace = TRUE)]
    extra_mi[, `:=`(InternSituation = "", RemedyIdea = "")]
    for (metric in c("Mood", "Sleep", "Steps")) {
        n_metric <- extra_mi[Metric == metric, .N]
        situations_file <- paste0("Situations_", metric, ".txt")
        situations <- read_text_file(situations_file)
        situation_labels <- as.character(cut(seq_len(n_metric),
            breaks = length(situations),
            labels = situations, include.lowest = TRUE
        ))
        extra_mi[Metric == metric, InternSituation := sample(situation_labels)]
    }
    for (metric in c("Mood", "Sleep", "Steps")) {
        n_metric <- extra_mi[Metric == metric, .N]
        ideas_file <- paste0("Ideas_", metric, ".txt")
        ideas <- read_text_file(ideas_file)
        idea_labels <- as.character(cut(seq_len(n_metric),
            breaks = length(ideas),
            labels = ideas, include.lowest = TRUE
        ))
        extra_mi[Metric == metric, RemedyIdea := sample(idea_labels)]
    }
    combinations <- rbind(combinations, extra_mi)
}

# Add an index for file naming
combinations[, Index := .I]

# Generate command lines for each combination and write them to a file
cmd_lines <- "#!/bin/bash"
for (i in seq_len(nrow(combinations))) {
    cmd_line <- generate_prompt(combinations[i, ], part1, chain_of_thought, results_dir)
    cmd_lines <- c(cmd_lines, cmd_line)
}
cmd_lines_file <- file.path(results_dir, "cmd_lines.sh")
write(cmd_lines, cmd_lines_file, sep = "\n", append = FALSE)
system(paste("chmod +x", shQuote(cmd_lines_file)))

# Save combinations to file for reference
fwrite(combinations, file.path(results_dir, "combinations.txt"), sep = "\t", quote = FALSE, row.names = FALSE)

cat("Prompt generation complete. Command lines saved to:", cmd_lines_file, "\n")
