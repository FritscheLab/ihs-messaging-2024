# scripts/R/03_format_output.R
# -----------------------------------------------------------
# This script reads the generated message result files, merges them with
# combination metadata, formats the output into a final structured table,
# and exports the results as an Excel workbook with conditional formatting.
#
# Make sure to run this script after the prompt generation and API call steps.
# -----------------------------------------------------------

library(data.table)
library(openxlsx)

# Define global directories (assumed working directory is the repository root)
base_dir <- getwd()
results_dir <- file.path(base_dir, "results")

# Read combinations metadata (generated in 01_generate_prompts.R)
combinations_file <- file.path(results_dir, "combinations.txt")
if (!file.exists(combinations_file)) {
    stop("Combinations file not found. Please ensure 01_generate_prompts.R has been executed: ", shQuote(combinations_file))
}
combinations <- fread(combinations_file, sep = "\t", quote = "")

# List all message result files (assuming they contain "message_results" in the filename)
res_files <- list.files(results_dir, pattern = "message_results", full.names = TRUE)

# Read and combine message results
new_messages_list <- list()
for (file in res_files) {
    # Extract file prefix from filename (remove suffix and split by underscore)
    base_name <- basename(file)
    file_prefix <- sub("_message_results.txt$", "", base_name)
    parts <- strsplit(file_prefix, "_")[[1]]

    # Ensure the prefix has at least 7 parts: Index, Metric, Function, Interval, DataContextName, ApproachName, Question
    if (length(parts) < 7) {
        warning("Filename does not conform to expected format: ", shQuote(base_name))
        next
    }

    # Create a data.table with file metadata
    res_info <- data.table(
        Index = as.numeric(parts[1]),
        Metric = parts[2],
        Function = parts[3],
        Interval = parts[4],
        DataContextName = parts[5],
        ApproachName = parts[6],
        Question = parts[7]
    )

    # Read the message results (assumes two columns: Level and Message)
    res <- fread(file, sep = "\t", colClasses = "character")
    # Combine file metadata with the results
    res <- cbind(res_info, res)
    new_messages_list[[file]] <- res
}

# Combine all messages into a single data.table
if (length(new_messages_list) == 0) {
    stop("No message result files found in ", shQuote(results_dir))
}
new_messages <- rbindlist(new_messages_list)

# Optional: Format ApproachName to add space between lowercase and uppercase letters
new_messages[, ApproachName := gsub("([a-z])([A-Z])", "\\1 \\2", ApproachName)]

# Merge with combinations metadata for additional context (using key columns)
merge_cols <- c("Index", "Metric", "Function", "Interval", "DataContextName", "ApproachName", "Question")
new_messages <- merge(new_messages, combinations, by = merge_cols, sort = FALSE)

# Save merged messages for reference
fwrite(new_messages, file.path(results_dir, "new_messages.txt"), sep = "\t", quote = FALSE)

# Add a MessageSubID column: Neutral = 1, Low = 2, Medium = 3, High = 4
new_messages[, MessageSubID := fifelse(
    Level == "Neutral", 1,
    fifelse(
        Level == "Low", 2,
        fifelse(Level == "Medium", 3, 4)
    )
)]

# Create final formatted output table
ihs_format_output <- new_messages[, .(
    "Notification Identifier" = paste0("Internship2024-", Index, "-", MessageSubID),
    "Core Message ID" = Index,
    "Notification Date" = "n/a",
    "Metric" = paste0("Metric_", Metric, "_", Function, "_", Interval),
    "Trigger Value" = fifelse(Level == "Neutral", "TRUE", ""),
    "Trigger Low" = fifelse(
        Level %in% c("Neutral", "Low"),
        "",
        fifelse(Level == "Medium", as.character(LowerQuantile), as.character(UpperQuantile))
    ),
    "Trigger High" = fifelse(
        Level == "Low", as.character(LowerQuantile),
        fifelse(Level == "Medium", as.character(UpperQuantile), "")
    ),
    "Text" = Message,
    MetricName, FunctionName, IntervalName, DataContext, ApproachName, Question, InternSituation, RemedyIdea
)]

# Create an Excel workbook and add the formatted data with styling
output_excel <- file.path(results_dir, "ihs_messages.xlsx")
wb <- createWorkbook()
addWorksheet(wb, "Messages")

# Write the data to the worksheet
writeData(wb, sheet = "Messages", ihs_format_output, startCol = 1, startRow = 1, colNames = TRUE)

# Create a header style
header_style <- createStyle(
    fontColour = "black", fgFill = "#FFFFFF",
    halign = "center", border = "TopBottom", textDecoration = "bold"
)
addStyle(wb, sheet = "Messages", style = header_style, rows = 1, cols = 1:ncol(ihs_format_output), gridExpand = TRUE)

# Apply alternating row shading for better readability
n_rows <- nrow(ihs_format_output)
for (i in seq_len(n_rows)) {
    # Every group of 4 rows (corresponding to message levels) gets alternating background
    if ((((i - 1) %/% 4) %% 2) == 0) {
        row_style <- createStyle(fgFill = "grey70")
        addStyle(wb, sheet = "Messages", style = row_style, rows = i + 1, cols = 1:ncol(ihs_format_output), gridExpand = TRUE)
    }
}

# Adjust column widths automatically
setColWidths(wb, sheet = "Messages", cols = 1:ncol(ihs_format_output), widths = "auto")

# Save the workbook
saveWorkbook(wb, output_excel, overwrite = TRUE)

cat("Output formatting complete. Excel file saved to:", shQuote(output_excel), "\n")
