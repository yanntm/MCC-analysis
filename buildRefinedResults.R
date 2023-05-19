library(stringr)  # Load the package
library(dplyr)
library(tidyr)
library(writexl)
library(VennDiagram)


# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Set the current year, default to 2023 if not provided
current_year <- if (length(args) >= 1) as.integer(args[1]) else 2023


# Set default values for input file and output folder
input_file <- "raw-result-analysis.csv"
output_folder <- "website"

raw_result_analysis <- read.csv(file = input_file,  dec = ".", sep = ",",  header = TRUE, stringsAsFactors = FALSE)

if (current_year == 2019) {
  raw_result_analysis$Examination[raw_result_analysis$Examination == "GlobalProperties"] <- "ReachabilityDeadlock"
}

df <- raw_result_analysis
df <- rename(df, tool = "X....tool")
df <- separate(df, "flags.bonus.scores.mask", into = c("flags", "bonus", "score", "mask"), sep = ":")

# Filter out rows where 'tool' starts with "BVT"
# their format is inconsistent with the rest, and we recompute it ourselves anyway
# df <- df[!grepl("^BVT", df$tool),]

# Split mask column into individual characters
max_mask_width <- max(nchar(gsub("[\\s?-]+", "", df$mask)))  # Get the widest mask

# Handle rows that are only a single question mark
df$results[df$results == "?"] <- paste(rep(NA, max_mask_width), collapse=" ")

# Handle rows that are numbers (possibly in scientific notation) separated by spaces, or T/F/? strings
df$results <- lapply(df$results, function(x) {
  # If the string contains only T, F or ?, treat each character as a separate value
  if (grepl("^[TF?]+$", x)) {
    split_result <- strsplit(x, "")[[1]]
  } else {
    # Otherwise, split string into individual values based on spaces
    split_result <- strsplit(x, " ")[[1]]
  }
  
  # If less than max_mask_width, pad with NAs
  if (length(split_result) < max_mask_width) {
    split_result <- c(split_result, rep(NA, max_mask_width - length(split_result)))
  }
  
  # If more than max_mask_width, truncate
  if (length(split_result) > max_mask_width) {
    split_result <- split_result[1:max_mask_width]
  }
  
  # Join the split_result back together into a single string with values separated by spaces
  return(paste(split_result, collapse=" "))
})

# Now we should be able to use the separate function without errors
df <- separate(df, "results", into = paste0("ver_", seq_len(max_mask_width)), sep = " ", convert = TRUE)


handle_mask <- function(mask, max_mask_width) {
  # Split string into individual characters
  split_mask <- strsplit(mask, "")[[1]]
  
  # Replace "?" and "-" with NA
  split_mask[split_mask %in% c("?", "-")] <- NA
  
  # If less than max_mask_width, pad with NAs
  if (length(split_mask) < max_mask_width) {
    split_mask <- c(split_mask, rep(NA, max_mask_width - length(split_mask)))
  }
  
  # If more than max_mask_width, emit a warning and truncate
  if (length(split_mask) > max_mask_width) {
    warning(paste("Mask has more characters than max_mask_width. Truncating... Original mask:", mask))
    split_mask <- split_mask[1:max_mask_width]
  }
  
  return(paste(split_mask, collapse=" "))
}

# Apply the function to the mask column
df$mask <- lapply(df$mask, handle_mask, max_mask_width=max_mask_width)

# Separate the mask and results into individual columns
df <- separate(df, mask, into=paste0("res_", seq_len(max_mask_width)), sep=" ", convert=TRUE)

# Pivot longer for the 'ver_' columns
df_ver <- df %>%
  pivot_longer(cols = starts_with("ver_"), names_to = "ID", values_to = "verdict") %>%
  mutate(ID = str_replace(ID, "ver_", ""))  # Remove "ver_" from ID

# Pivot longer for the 'res_' columns
df_res <- df %>%
  pivot_longer(cols = starts_with("res_"), names_to = "ID", values_to = "result") %>%
  mutate(ID = str_replace(ID, "res_", ""))  # Remove "res_" from ID

# Join the two data frames
df_long <- left_join(df_ver, df_res, by = c("tool", "Input", "Examination", "ID"))

# Select the desired columns
df_long <- df_long %>%
  select(tool, Input, Examination, ID, result, verdict)

df_long <- df_long %>%
  group_by(tool, Input, Examination, ID) %>%
  filter(!all(is.na(result))) %>%
  ungroup()

df_long <- rename(df_long, Tool = "tool")
df_long <- rename(df_long, Verdict = "result")
df_long <- rename(df_long, Result = "verdict")

df_long <- df_long %>%
  separate(Input, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-")

write.csv(df_long, "refined-result.csv", row.names = FALSE)


