library(stringr)  # Load the package
library(dplyr)
library(tidyr)

# Read the data
df <- read.csv("refined-result-bvt.csv")

# Load models.csv
models_df <- read.csv("models.csv")


# Function to process a single category
process_category <- function(df, category_name, examinations, model_type = NULL) {
  # Filter the data to include only the specified examinations
  df_category <- df %>%
    filter(Examination %in% examinations)
  
  # If a model type is provided, filter data based on the model type
  if (!is.null(model_type)) {
    df_category <- df_category %>%
      filter(ModelType == model_type)
  }
  
  # Calculate the number of models for the given model type
  num_models <- if (is.null(model_type)) {
    nrow(models_df)
  } else {
    nrow(models_df %>%
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
  write.csv(df_summary, paste0(category_name, ".csv"), row.names = FALSE)
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


model_types <- c("COL", "PT")
for (model_type in model_types) {
  for (category_name in names(categories)) {
    process_category(df, paste0(category_name, "_", model_type), categories[[category_name]], model_type)
  }
}

# Process the category without filtering by ModelType
for (category_name in names(categories)) {
  process_category(df, category_name, categories[[category_name]])
}
