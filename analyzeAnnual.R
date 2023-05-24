library(stringr)  # Load the package
library(dplyr)
library(tidyr)
library(ggplot2)


# Get list of year folders, assuming they're directly in the working directory
year_folders <- list.files(path = ".", full.names = FALSE, pattern = "^\\d{4}$")

# First pass: read data and find all columns
all_years_data <- list()
all_columns <- NULL

for (year in year_folders) {
  df_year <- read.csv(paste0(year, "/answers.csv"), stringsAsFactors = FALSE)
  df_year$year <- year
  all_years_data[[year]] <- df_year
  all_columns <- unique(c(all_columns, colnames(df_year)))
}

# Second pass: add missing columns
for (year in year_folders) {
  missing_columns <- setdiff(all_columns, colnames(all_years_data[[year]]))
  all_years_data[[year]][missing_columns] <- NA
}

# Combine all data
combined_data <- do.call(rbind, all_years_data)

combined_data$year <- as.numeric(as.character(combined_data$year))

# Curate the Tool names
combined_data$Tool <- case_when(
  combined_data$Tool %in% c("MARCIE", "Marcie") ~ "Marcie",
  combined_data$Tool %in% c("Smart", "smart") ~ "Smart",
  combined_data$Tool %in% c("TINA.tedd", "tedd", "tedd-c") ~ "tedd",
  combined_data$Tool == "LoLa" ~ "LoLA",
  combined_data$Tool == "LoLa+red" ~ "ITS-LoLa",
  combined_data$Tool == "ITS-Tools.L" ~ "ITS-Tools.M",
  combined_data$Tool == "Tapaal(SEQ)" ~ "Tapaal",
  grepl("^RBVT-", combined_data$Tool) ~ "RBVT",
  grepl("^BVT-", combined_data$Tool) ~ "BVT",
  combined_data$Tool %in% c("2018-Gold", "2019-Gold", "2020-gold", "2021-gold", "2022-gold") ~ "LastYear-gold",
  TRUE ~ combined_data$Tool
)

# Get the column names for examinations
answer_cols <- grep("^answer_", colnames(combined_data), value = TRUE)

# Replace 0 answers with NA (meaning the Tool did not participate)
combined_data[answer_cols] <- lapply(combined_data[answer_cols], function(x) replace(x, x == 0, NA))

# Define categories
categories <- list(
  state_space = c("StateSpace"),
  global_properties = c("Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe"),
  reachability = c("ReachabilityCardinality", "ReachabilityFireability"),
  ctl = c("CTLCardinality", "CTLFireability"),
  ltl = c("LTLCardinality", "LTLFireability"),
  upper_bounds = c("UpperBounds")
)
# do it again but for building the CSV
# Create a plot for each examination
# Loop over answer_XX columns
for (answer_col in answer_cols) {
  # Compute the name of the normalized answer column
  norm_answer_col <- paste0("norm_", answer_col)
  
  # Compute normalized answers for this examination
  combined_data2 <- combined_data %>%
    group_by(year) %>%
    mutate(ideal_answer = max(ifelse(Tool == "Ideal Tool", .data[[answer_col]], 0))) %>%
    mutate(answer_ideal = .data[[answer_col]] / ideal_answer * 100) %>%
    ungroup()

  # Compute the BVT answer for each year
  combined_data2 <- combined_data2 %>%
    group_by(year) %>%
    mutate(bvt_answer = max(ifelse(Tool == "BVT", .data[[answer_col]], 0))) %>%
    ungroup()

  # Compute the percentage of the BVT answer
  combined_data2 <- combined_data2 %>%
    mutate(answer_bvt = .data[[answer_col]] / bvt_answer * 100)

  # Filter out Tools with NA values for answer_ideal and answer_bvt
  combined_data2 <- combined_data2 %>%
    filter(!is.na(answer_ideal), !is.na(answer_bvt)) %>%
    rename(answer = answer_col)
  
  # Select only the columns we're interested in
  combined_data2 <- combined_data2 %>%
    select(Tool, year, answer, answer_ideal, answer_bvt)
  
  # Write the data frame to a CSV file in the "csv" directory
  write.csv(combined_data2, file = paste0("./csv/", gsub(" ", "_", answer_col), "_time.csv"), row.names = FALSE)
}

# New loop for each category
for (category in names(categories)) {
  category_examinations = categories[[category]]
  
  # Start with an empty data frame for this category
  category_data <- data.frame()
  
  for (examination in category_examinations) {
    # Read the examination data
    examination_data <- read.csv(paste0("./csv/answer_", examination, "_time.csv"))
    
    # If the category data is empty, initialize it with the examination data
    if (nrow(category_data) == 0) {
      category_data <- examination_data
    } else {
      # If the category data is not empty, merge it with the examination data and sum the answers
      examination_data <- examination_data %>%
        select(Tool, year, answer)  # Keep only the columns we need to merge and sum
      
      category_data <- merge(category_data, examination_data, by = c("Tool", "year"), all = TRUE)
      category_data <- category_data %>%
        mutate(answer = rowSums(.[, c("answer.x", "answer.y")], na.rm = TRUE)) %>%
        select(-c(answer.x, answer.y))
    }
  }
  
  # Compute the ideal and BVT normalized answers for this category
  category_data <- category_data %>%
    group_by(year) %>%
    mutate(ideal_answer = max(ifelse(Tool == "Ideal Tool", answer, 0))) %>%
    mutate(answer_ideal = answer / ideal_answer * 100) %>%
    ungroup()

  category_data <- category_data %>%
    group_by(year) %>%
    mutate(bvt_answer = max(ifelse(Tool == "BVT", answer, 0))) %>%
    ungroup()

  category_data <- category_data %>%
    mutate(answer_bvt = answer / bvt_answer * 100)

  # Remove the unneeded columns before writing to CSV
  category_data <- category_data %>%
    select(Tool, year, answer, answer_ideal, answer_bvt)

  # Write the data frame to a CSV file in the "csv" directory
  write.csv(category_data, file = paste0("./csv/answer_", category, "_time.csv"), row.names = FALSE)
}
