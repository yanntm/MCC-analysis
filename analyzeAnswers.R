library(stringr)  # Load the package
library(dplyr)
library(tidyr)
library(writexl)


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

# Count number of 'T' or 'X' in 'mask' column for each tool and examination combination
scores <- df %>%
  group_by(tool, Examination) %>%
  summarize(score = sum(str_count(mask, "[T]")), errors = sum(str_count(mask, "[X]")))

# Calculate the number of models for each examination
num_models <- df %>%
  group_by(Examination) %>%
  summarize(models = n_distinct(Input))


# Add the ideal tool row to the scores data frame
ideal_tool_scores <- num_models %>%
  mutate(tool = "Ideal Tool",
         score = case_when(
           Examination == "StateSpace" ~ models * 4,
           Examination %in% c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe") ~ models,
           Examination %in% c("ReachabilityCardinality", "ReachabilityFireability", "CTLCardinality", "CTLFireability",
                              "LTLCardinality", "LTLFireability","UpperBounds") ~ models * 16
         ),
         errors = 0)

ideal_tool_scores <- ideal_tool_scores[,-c(2)]
scores <- rbind(scores, ideal_tool_scores)


# Split mask column into individual characters
max_mask_width <- max(nchar(gsub("[\\s?-]+", "", df$mask)))  # Get the widest mask
df_mask_split <- strsplit(gsub("[\\s?-]+", "", df$mask), "")  # Split mask into individual characters, replacing "?" and "-" with an empty string
df_mask_split <- lapply(df_mask_split, function(x) c(x, rep(NA, max_mask_width - length(x))))  # Pad with NA as needed
df_mask_split <- do.call(rbind, df_mask_split)  # Convert list to dataframe
colnames(df_mask_split) <- paste0("res_", seq_len(max_mask_width))

# Combine the original and split mask dataframes
df_new <- cbind(df[, 1:3], df_mask_split)
colnames(df_new)

# Load the required libraries
library(VennDiagram)

# Reshape the data frame into long format
df_long <- pivot_longer(df_new, cols = starts_with("Input"), names_to = "Input_index", values_to = "Input") %>%
  pivot_longer(cols = starts_with("res"), names_to = "result_index", values_to = "result")

df_long <- unite(df_long, "Input", c("Input", "result_index"), sep = "_")
df_long <- df_long[,c(1,2,4,5)]

# Function to generate Venn diagrams for a given category
generate_venn_diagrams <- function(df_category, category_name) {
  # Split the dataframe by the tool column
  tools_list <- split(df_category, df_category$tool)
  
  # Create a list of non-NA results for each tool
  tool_results <- lapply(tools_list, function(tool_df) {
    tool_df %>%
      filter(!is.na(result) & result != "X") %>%
      select(Input, result) %>%
      unique()
  })
  
  # Compute the BVT results as the union of other tools' results
  bvt_results <- unique(do.call(rbind, tool_results))
  
  # Add a name for the BVT results and append it to the tool_results list
  names(bvt_results) <- paste0("RBVT-", current_year)
  tool_results <- c(tool_results, list(bvt_results))
  
  # Calculate set sizes for each index
  sets <- lapply(tool_results, function(x) x$Input)
  set_sizes <- sapply(sets, function(x) length(x))
  
  # Filter out tools with a set size of 0 (i.e., the tool did not participate in the category)
  non_empty_indices <- which(set_sizes != 0)
  tool_results <- tool_results[non_empty_indices]
  set_sizes <- set_sizes[non_empty_indices]
  
  # Get order of set sizes
  set_order <- order(set_sizes, decreasing = TRUE)
  
  # Use order to create sorted list of tools
  sorted_tools <- tool_results[set_order]
  
  # Create Venn diagrams for each tool and its two next ones
  for (i in 1:(length(sorted_tools) - 2)) {
    # Get current tool and its two next ones
    current_tool <- sorted_tools[[i]]$Input
    next_tool_1 <- sorted_tools[[i + 1]]$Input
    next_tool_2 <- sorted_tools[[i + 2]]$Input
    
    # Create Venn diagram with these tools
    tool_names <- names(sorted_tools)
    venn.diagram(
      x = list(current_tool = sorted_tools[[i]]$Input,
               next_tool_1 = sorted_tools[[i + 1]]$Input,
               next_tool_2 = sorted_tools[[i + 2]]$Input),
      category.names = tool_names[c(i, i + 1, i + 2)],
      filename = paste0(output_folder, "/", category_name, "_", i, "_venn.tiff"),
      main = paste(category_name, ":", tool_names[i], "(", set_sizes[set_order[i]], ") vs",
                   tool_names[i + 1], "(", set_sizes[set_order[i + 1]], ") vs",
                   tool_names[i + 2], "(", set_sizes[set_order[i + 2]], ")"),
      
      output = TRUE
    )
  }
  
}


# Define categories
categories <- list(
  state_space = c("StateSpace"),
  global_properties = c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe"),
  reachability = c("ReachabilityCardinality", "ReachabilityFireability"),
  ctl = c("CTLCardinality", "CTLFireability"),
  ltl = c("LTLCardinality", "LTLFireability"),
  upper_bounds = c("UpperBounds")
)

# Iterate through each category to create Venn diagrams
for (category_name in names(categories)) {
  examinations <- categories[[category_name]]
  df_category <- subset(df_long, Examination %in% examinations)
  df_category <- unite(df_category, "Input", c("Examination", "Input"), sep = "_")
  
  # Call the generate_venn_diagrams function for the current category
  generate_venn_diagrams(df_category, category_name)
}


compute_bvt_score <- function(df, examination) {
  df_examination <- df %>%
    filter(Examination == examination) %>%
    unite(Input, c("Examination", "Input"), sep = "_")
  
  tools_list <- split(df_examination, df_examination$tool)
  
  tool_results <- lapply(tools_list, function(tool_df) {
    tool_df %>%
      filter(!is.na(result)& result != "X") %>%
      select(Input, result) %>%
      unique()
  })
  
  bvt_results <- unique(do.call(rbind, tool_results))
  
  # Debug step: Compare the answer sets of BVT-2023 and RBVT
  if ("BVT-2023" %in% names(tools_list)) {
    bvt_2023_results <- tools_list[["BVT-2023"]] %>%
      filter(!is.na(result)) %>%  # Filter out NA elements from BVT-2023
      select(Input, result) %>%
      unique()
    
    rbvt_only <- setdiff(bvt_results, bvt_2023_results)
    bvt_2023_only <- setdiff(bvt_2023_results, bvt_results)
    
    if (nrow(rbvt_only) > 0 || nrow(bvt_2023_only) > 0) {
      cat("\nExamination:", examination)
      cat("\nRBVT-2023 only results:\n")
      print(rbvt_only)
      cat("\nBVT-2023 only results:\n")
      print(bvt_2023_only)
    }
  }
  
  return(nrow(bvt_results))
}

unique_examinations <- unique(df_long$Examination)

for (examination in unique_examinations) {
  bvt_score <- compute_bvt_score(df_long, examination)
  scores <- rbind(scores, data.frame(Examination = examination, score = bvt_score, tool = paste0("RBVT-", current_year), errors = 0))
}



# Pivot the table wider, creating separate columns for scores and errors
scores_wide <- scores %>%
  pivot_wider(names_from = Examination,
              values_from = c(score, errors),
              names_sep = "_")


# Assuming df is your input dataframe with N = 2K + 1 columns
n_cols <- ncol(scores_wide)
middle_index <- (n_cols + 1) %/% 2

# Generate a new index sequence by interleaving the first and second half indices
new_indices <- c(1, matrix(c(2:middle_index, (middle_index+1):n_cols), nrow = 2, byrow = T))

# Reorder the columns of the dataframe based on the new index sequence
scores_wide <- scores_wide[, new_indices]

# Print the answer counts for each tool
# write.csv(scores_wide, file = "answers.csv", row.names = FALSE)

df_reordered <- scores_wide
# StateSpace table
df_state_space <- df_reordered[, c("tool", "score_StateSpace", "errors_StateSpace")]
df_state_space <- df_state_space[rowSums(df_state_space[, "score_StateSpace"]) != 0,]
write.csv(df_state_space, "state_space.csv", row.names = FALSE)

create_table <- function(df, properties) {
  score_columns <- paste0("score_", properties)
  errors_columns <- paste0("errors_", properties)
  
  # Filter out columns that don't exist in the dataframe
  existing_score_columns <- score_columns[score_columns %in% colnames(df)]
  existing_errors_columns <- errors_columns[errors_columns %in% colnames(df)]
  
  combined_columns <- c()
  for (i in seq_along(existing_score_columns)) {
    combined_columns <- c(combined_columns, existing_score_columns[i], existing_errors_columns[i])
  }
  
  df_result <- df[, c("tool", combined_columns)]
  df_result$score_total <- rowSums(df_result[, existing_score_columns], na.rm = TRUE)
  df_result$error_total <- rowSums(df_result[, existing_errors_columns], na.rm = TRUE)
  df_result <- df_result[, c("tool", "score_total", "error_total", combined_columns)]
  
  # Filter out tools with a score of 0 for all examinations in the table
  df_result <- df_result[rowSums(df_result[, existing_score_columns], na.rm = TRUE) != 0,]
  return(df_result)
}


# Global properties table
global_properties <- c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe")
df_global_properties <- create_table(df_reordered, global_properties)
write.csv(df_global_properties, "global_properties.csv", row.names = FALSE)

# Reachability table
reachability_properties <- c("ReachabilityCardinality", "ReachabilityFireability")
df_reachability <- create_table(df_reordered, reachability_properties)
write.csv(df_reachability, "reachability.csv", row.names = FALSE)

# CTL table
ctl_properties <- c("CTLCardinality", "CTLFireability")
df_ctl <- create_table(df_reordered, ctl_properties)
write.csv(df_ctl, "ctl.csv", row.names = FALSE)

# LTL table
ltl_properties <- c("LTLCardinality", "LTLFireability")
df_ltl <- create_table(df_reordered, ltl_properties)
write.csv(df_ltl, "ltl.csv", row.names = FALSE)

# UpperBounds table
df_upper_bounds <- df_reordered[, c("tool", "score_UpperBounds", "errors_UpperBounds")]
df_upper_bounds <- df_upper_bounds[rowSums(df_upper_bounds[, "score_UpperBounds"]) != 0,]
write.csv(df_upper_bounds, "upper_bounds.csv", row.names = FALSE)
