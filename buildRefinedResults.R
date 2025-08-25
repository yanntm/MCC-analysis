library(stringr)  # Load the package
library(dplyr)
library(tidyr)
library(jsonlite)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Set the current year, default to 2023 if not provided
current_year <- if (length(args) >= 1) as.integer(args[1]) else 2024

# Set default values for input file and output folder
input_file <- "raw-result-analysis.csv"
output_folder <- "website"

raw_result_analysis <- read.csv(file = input_file,  dec = ".", sep = ",",  header = TRUE, stringsAsFactors = FALSE)

# Just for 2019 where ReachabilityDeadlock was renamed.
raw_result_analysis$Examination[raw_result_analysis$Examination == "GlobalProperties"] <- "ReachabilityDeadlock"

df <- raw_result_analysis

rm(raw_result_analysis)

df <- rename(df, tool = "X....tool")
df <- separate(df, "flags.bonus.scores.mask", into = c("flags", "bonus", "score", "mask"), sep = ":")


# Parse the "Input" column into the "ModelFamily", "ModelType", "ModelInstance" columns
df_models <- df %>% 
  separate(Input, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-", remove = FALSE)

# Select the "ModelFamily", "ModelType", "ModelInstance" columns and remove duplicate rows
df_models <- unique(df_models[, c("ModelFamily", "ModelType", "ModelInstance")])

# Export the unique models to a CSV file
write.csv(df_models, "models.csv", row.names = FALSE)


# Filter out rows where 'tool' starts with "BVT"
# their format is inconsistent with the rest, and we recompute it ourselves anyway
df <- df[!grepl("^BVT", df$tool),]

# Filter out rows where 'Input' starts with "S_"
# these are the "Stripped" models we had in earlier editions of the MCC.
df <- df[!grepl("^S_", df$Input),]

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
df <- separate(df, "results", into = paste0("ver_", seq_len(max_mask_width)), sep = " ", convert = FALSE)

# Replace "DNF" and "DNC" values with NA in the ver_1 column
df <- df %>%
  mutate(ver_1 = ifelse(ver_1 %in% c("DNF", "DNC"), NA, ver_1))


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
df <- separate(df, mask, into=paste0("res_", seq_len(max_mask_width)), sep=" ", convert=FALSE)

{
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

rm(df_res)
rm(df_ver)

# Select the desired columns
df_long <- df_long %>%
  select(tool, Input, Examination, ID, result, verdict)

df_long <- df_long %>%
  replace(., . == "NA", NA) %>%
  filter(!is.na(result)) %>%
  group_by(tool, Input, Examination, ID) %>%
  filter(!all(is.na(result))) %>%
  ungroup()

df_long <- rename(df_long, Tool = "tool")
df_long <- rename(df_long, Verdict = "result")
df_long <- rename(df_long, Result = "verdict")

df_long <- df_long %>%
  separate(Input, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-")

df <- df_long
rm(df_long)
df <- df %>% replace(., . == "NA", NA)
}

{
# Clone the df
df_bvt <- df

# Rename the Tool to BVT
df_bvt$Tool <- "BVT"

# Remove rows with "X" as Verdict
df_bvt <- df_bvt[df_bvt$Verdict == "T",]

# Keep only unique rows
df_bvt <- df_bvt[!duplicated(df_bvt),]

# Consistency check
df_bvt_no_result <- df_bvt
df_bvt_no_result$Result <- NULL
if(nrow(df_bvt_no_result[!duplicated(df_bvt_no_result),]) != nrow(df_bvt)) {
  print("Warning: Number of unique rows differs when ignoring 'Result'")
}
rm(df_bvt_no_result)

# Bind the rows back to the original dataframe
df <- rbind(df, df_bvt)
}

df <- df %>% replace(., . == "NA", NA)

# Export the refined data to a CSV file
# write.csv(df, "refined-result-bvt.csv", row.names = FALSE)

df <- df %>%
  filter(!is.na(Verdict))

colnames(df)


# Define categories
categories <- list(
  state_space = c("StateSpace"),
  global_properties = c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe"),
  reachability = c("ReachabilityCardinality", "ReachabilityFireability"),
  ctl = c("CTLCardinality", "CTLFireability"),
  ltl = c("LTLCardinality", "LTLFireability"),
  upper_bounds = c("UpperBounds")
)

# Define tool families
tool_families <- list(list("tedd-c", "tedd-s", "tedd"), 
                      list("ITS-Tools", "ITS-Tools.M", "ITS-Tools.L", "ITS-Lola", "LTSMin+red", "Marcie+red", "Smart+red", "LoLa+red", "GreatSPN+red"),
                      list("M4M.full","M4M.struct"),
                      list("Irma.full","Irma.struct"),
                      list("Tapaal(EXP)","Tapaal(PAR)","Tapaal")
                      #... add more here as needed
                      )


# Define a function to generate the tool-query matrix
generate_tool_query_matrix <- function(tool_index_data, resolution_length) {
  # Initialize a matrix with zeros
  tool_query_matrix <- matrix(0, nrow = resolution_length, ncol = length(tool_index_data), 
                              dimnames = list(NULL, names(tool_index_data)))
  
  # For each tool in tool_index_data
  for (tool in names(tool_index_data)) {
    # Get the indices for which the tool provided a solution
    indices <- tool_index_data[[tool]]$answers
    indices <- as.integer(indices)
    
    # Use vectorized assignment to set the solved queries to 1
    tool_query_matrix[indices, tool] <- 1
  }
  
  return(tool_query_matrix)
}

get_tool_family_dict <- function(tool_families, all_tools) {
  tool_family_dict <- list()
  next_family_index <- length(tool_families) + 1  # Start assigning new families after predefined ones
  
  for(i in seq_along(tool_families)) {
    for(tool in tool_families[[i]]) {
      tool_family_dict[[tool]] <- i
    }
  }
  
  for(tool in all_tools) {
    if(!(tool %in% names(tool_family_dict))) {
      # If a tool is not part of any predefined family, assign a new family to it
      tool_family_dict[[tool]] <- next_family_index
      next_family_index <- next_family_index + 1
    }
  }
  
  return(tool_family_dict)
}




# Define a function to add the hardness metric
add_hardness_metric <- function(resolution, tool_query_matrix, tool_family_dict) {
  # Initialize the hardness metric with zeros
  hardness_metric <- numeric(nrow(tool_query_matrix))
  
  # For each query in the tool_query_matrix
  for(i in seq_len(nrow(tool_query_matrix))) {
    # Find the indices of the tools that provided a solution
    solution_indices <- which(tool_query_matrix[i, ] == 1)
    solution_tools <- colnames(tool_query_matrix)[solution_indices]
    
    # Filter out the virtual tools
    solution_tools <- solution_tools[!(solution_tools %in% c("BVT", "LastYear-gold"))]
    
    # Check if any solution_tool is not in tool_family_dict
    for(tool in solution_tools) {
      if(!(tool %in% names(tool_family_dict))) {
        # If tool not in tool_family_dict, print debugging info
        print(paste("Tool not found in tool_family_dict:", tool))
        print("Current solution_tools:")
        print(solution_tools)
        print("Current tool_family_dict:")
        print(tool_family_dict)
      }
    }
    
    # Get the families of the solution tools
    solution_families <- unique(sapply(solution_tools, function(tool) tool_family_dict[[tool]]))
    
    # Compute the hardness metric: count the number of different families, bound the result by 3
    hardness_metric[i] <- min(length(solution_families), 3)
  }
  
  # Add the hardness metric to the resolution data frame
  resolution$Solutions <- hardness_metric
  
  return(resolution)
}


# Loop over categories
for (category_name in names(categories)) {
  
  # Get the category's examinations
  category_examinations <- categories[[category_name]]
  
  # Filter df to only include rows where Examination is in category_examinations
  df_category <- df[df$Examination %in% category_examinations, ]
  
  # Create a unique index based on unique tuples for the category where Verdict is "T"
  resolution_category <- df_category[df_category$Verdict == "T",] %>%
    select(ModelFamily, ModelType, ModelInstance, Examination, ID, Result) %>%
    distinct() %>%
    rename(Consensus = Result) %>%
    mutate(Index = row_number())

  # Left join df_category with resolution_category to get the new Index
  df_category <- df_category %>%
    left_join(resolution_category, by = c("ModelFamily", "ModelType", "ModelInstance", "Examination" , "ID")) %>%
    select(Tool, Index, Verdict)

  # Reorder the column named "Index" to be the first column
  resolution_category <- resolution_category[, c("Index", setdiff(names(resolution_category), "Index"))]
  
  # Decrease 'ID' by 1 and pad it with leading zeros
  resolution_category <- resolution_category %>%
    mutate(ID = str_pad(as.integer(ID) - 1, width = 2, side = "left", pad = "0"))
  
  # Create the category directory if it does not exist
  if (!dir.exists(category_name)){
    dir.create(category_name)
  }

  # Now you can split the df_category into separate entries for each Tool
  tools <- unique(df_category$Tool)
  tool_index_dict <- list()
  for (tool in tools) {
    # Filter rows for the current tool
    df_tool <- df_category[df_category$Tool == tool,]

    # Separate indexes where Verdict is T and Verdict is X
    verdict_T <- df_tool[df_tool$Verdict == "T",]$Index
    verdict_F <- df_tool[df_tool$Verdict == "X",]$Index

    # Sort the vectors
    verdict_T <- sort(verdict_T)
    verdict_F <- sort(verdict_F)

    # Convert numeric indices to string
    verdict_T <- as.character(verdict_T)
    verdict_F <- as.character(verdict_F)

    # Create a list to store in JSON
    tool_index_dict[[tool]] <- list(answers = verdict_T, errors = verdict_F)
  }

  # Generate the tool-query matrix
  tool_query_matrix <- generate_tool_query_matrix(tool_index_dict, nrow(resolution_category))

  # Add the hardness metric to the resolution data frame
  all_tools <- unique(df_category$Tool)
  tool_family_dict <- get_tool_family_dict(tool_families, all_tools)
  resolution_category <- add_hardness_metric(resolution_category, tool_query_matrix, tool_family_dict)


  # Write the category's resolution to a CSV file in the category's directory
  write.csv(resolution_category, file.path(category_name, "resolution.csv"), row.names = FALSE)

  # Write to a JSON file in the category's directory
  write_json(tool_index_dict, file.path(category_name, "tool_index_dict.json"))
}



# Function to process a single category
process_category <- function(df, category_name, examinations, model_type = NULL) {
  # Filter the data to include only the specified examinations
  df_category <- df %>%
    filter(Examination %in% examinations)
  
  # Update the examinations variable to include only those present in df_category
  examinations <- unique(df_category$Examination)
  
  
  # If a model type is provided, filter data based on the model type
  if (!is.null(model_type)) {
    df_category <- df_category %>%
      filter(ModelType == model_type)
  }
  
  # Calculate the number of models for the given model type
  num_models <- if (is.null(model_type)) {
    nrow(df_models)
  } else {
    nrow(df_models %>%
           filter(ModelType == model_type))
  }
  # Define a function to calculate ideal scores for a given examination
  ideal_scores <- function(examination) {
    case_when(
      examination == "StateSpace" ~ num_models * 4,
      examination %in% c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe") ~ num_models,
      examination %in% c("ReachabilityCardinality", "ReachabilityFireability", "CTLCardinality", "CTLFireability",
                         "LTLCardinality", "LTLFireability","UpperBounds") ~ num_models * 16
    )
  }
  

  # Calculate total answers and errors for each tool
  total_summary <- df_category %>%
    group_by(Tool) %>%
    summarise(
      answer_total = sum(Verdict == "T", na.rm = TRUE),
      error_total = sum(Verdict == "X", na.rm = TRUE),
    )
  
  # Calculate answers and errors for each examination in the category
  exam_summary <- df_category %>%
    group_by(Tool, Examination) %>%
    summarise(
      answer = sum(Verdict == "T", na.rm = TRUE),
      error = sum(Verdict == "X", na.rm = TRUE),
    ) %>%
    pivot_wider(names_from = Examination, values_from = c(answer, error), names_sep = "_")
  
  # Join the total and examination-specific summaries
  df_summary <- left_join(total_summary, exam_summary, by = "Tool")

  # Reorder columns so each "answer" is followed by its "error"
  n_cols <- ncol(df_summary)
  middle_index <- (n_cols + 3) %/% 2 # Added 3 because we are starting from the 4th column
  new_indices <- c(1:3, matrix(c(4:middle_index, (middle_index+1):n_cols), nrow = 2, byrow = TRUE))
  df_summary <- df_summary[, new_indices]
 
  # Create an ideal tool row
  ideal_tool_row <- tibble(
    Tool = "Ideal Tool",
    answer_total = sum(sapply(examinations, ideal_scores)),
    error_total = 0
  )
  
  # Calculate ideal answers and errors for each examination in the category
  for (examination in examinations) {
    ideal_tool_row <- ideal_tool_row %>%
      mutate("{examination}_answer" := ideal_scores(examination), "{examination}_error" := 0)
  }
  
  # Make the names of the columns in ideal_tool_row match the names in df_summary
  names(ideal_tool_row) <- names(df_summary)

  
  # Add the ideal tool row to the summary dataframe
  df_summary <- rbind(df_summary, ideal_tool_row)
  
  # Write the result to a CSV file
  write.csv(df_summary, file.path(category_name, "scores.csv"), row.names = FALSE)
}

#model_types <- c("COL", "PT")
#for (model_type in model_types) {
#  for (category_name in names(categories)) {
#    process_category(df, paste0(category_name, "_", model_type), categories[[category_name]], model_type)
#  }
#}

# Process the category without filtering by ModelType
for (category_name in names(categories)) {
  process_category(df, category_name, categories[[category_name]])
}


# Initialize an empty data frame
answers_df <- data.frame()

# Loop over the category names
for (category_name in names(categories)) {
  
  # Read the category's scores.csv file
  scores_df <- read.csv(file.path(category_name, "scores.csv"))
  
  # Drop the 'answer_total' and 'error_total' columns
  scores_df <- scores_df %>% select(-c(answer_total, error_total))
  
  # If this is the first category, then answers_df is still empty and we can just copy scores_df into it
  if (nrow(answers_df) == 0) {
    answers_df <- scores_df
  } else {
    # Merge this category's data with the existing data
    # By using a full join, we make sure that all tools are included, even if they didn't participate in every category
    answers_df <- full_join(answers_df, scores_df, by = "Tool")
  }
  
}

# Fill NA values with 0
answers_df[is.na(answers_df)] <- 0

# Write the final dataframe to the answers.csv file
write.csv(answers_df, "./answers.csv", row.names = FALSE)



