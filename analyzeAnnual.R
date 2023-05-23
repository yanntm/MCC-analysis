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
score_cols <- grep("^answer_", colnames(combined_data), value = TRUE)

# Replace 0 scores with NA (meaning the Tool did not participate)
combined_data[score_cols] <- lapply(combined_data[score_cols], function(x) replace(x, x == 0, NA))

# Create a plot for each examination
# Loop over score_XX columns
for (score_col in score_cols) {
  # Compute the name of the normalized score column
  norm_score_col <- paste0("norm_", score_col)
  
  # Compute normalized scores for this examination
  combined_data2 <- combined_data %>%
    group_by(year) %>%
    mutate(ideal_score = max(ifelse(Tool == "Ideal Tool", .data[[score_col]], 0))) %>%
    mutate({{norm_score_col}} := .data[[score_col]] / ideal_score * 100) %>%
    ungroup()
  

  # Filter out Tools with NA values for norm_score_col
  combined_data2 <- combined_data2 %>% 
    filter(!is.na(.data[[norm_score_col]]))
  
  
  # Count the number of years each Tool participated in this examination
  Tool_counts <- combined_data2 %>% 
    filter(!is.na(.data[[norm_score_col]])) %>% 
    group_by(Tool) %>%
    summarise(n = n_distinct(year))
  
  # Add points for all Tools
  p <- ggplot(combined_data2, aes_string(x = "year", y = norm_score_col, color = "Tool")) +
    geom_point() +
    scale_x_continuous(breaks = unique(combined_data$year)) +
    labs(title = paste(score_col, "Score Over Time"), x = "Year", y = "Score (% of Ideal Tool)") +
    theme(legend.position = "bottom") +
    guides(color = guide_legend(ncol = 3, title = "Tool"))
  
  # Add lines for Tools that have participated more than once
  for (Tool in Tool_counts$Tool[Tool_counts$n > 1]) {
    p <- p + geom_line(data = combined_data2[combined_data2$Tool == Tool, ], aes_string(x = "year", y = norm_score_col, color = "Tool"))
  }
  
  # Save the plot as a PNG in the "plots" directory
  ggsave(filename = paste0("./", gsub(" ", "_", score_col), "_time.png"), plot = p, width = 10, height = 7, dpi = 300)
  
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
# do it again but for building the CSV
# Create a plot for each examination
# Loop over score_XX columns
for (score_col in score_cols) {
  # Compute the name of the normalized score column
  norm_score_col <- paste0("norm_", score_col)
  
  # Compute normalized scores for this examination
  combined_data2 <- combined_data %>%
    group_by(year) %>%
    mutate(ideal_score = max(ifelse(Tool == "Ideal Tool", .data[[score_col]], 0))) %>%
    mutate(score_ideal = .data[[score_col]] / ideal_score * 100) %>%
    ungroup()

  # Compute the BVT score for each year
  combined_data2 <- combined_data2 %>%
    group_by(year) %>%
    mutate(bvt_score = max(ifelse(Tool == "RBVT", .data[[score_col]], 0))) %>%
    ungroup()

  # Compute the percentage of the BVT score
  combined_data2 <- combined_data2 %>%
    mutate(score_bvt = .data[[score_col]] / bvt_score * 100)

  # Filter out Tools with NA values for score_ideal and score_bvt
  combined_data2 <- combined_data2 %>%
    filter(!is.na(score_ideal), !is.na(score_bvt)) %>%
    rename(score = score_col)
  
  # Select only the columns we're interested in
  combined_data2 <- combined_data2 %>%
    select(Tool, year, score, score_ideal, score_bvt)
  
  # Write the data frame to a CSV file in the "csv" directory
  write.csv(combined_data2, file = paste0("./csv/", gsub(" ", "_", score_col), "_time.csv"), row.names = FALSE)
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
      # If the category data is not empty, merge it with the examination data and sum the scores
      examination_data <- examination_data %>%
        select(Tool, year, score)  # Keep only the columns we need to merge and sum
      
      category_data <- merge(category_data, examination_data, by = c("Tool", "year"), all = TRUE)
      category_data <- category_data %>%
        mutate(score = rowSums(.[, c("score.x", "score.y")], na.rm = TRUE)) %>%
        select(-c(score.x, score.y))
    }
  }
  
  # Compute the ideal and BVT normalized scores for this category
  category_data <- category_data %>%
    group_by(year) %>%
    mutate(ideal_score = max(ifelse(Tool == "Ideal Tool", score, 0))) %>%
    mutate(score_ideal = score / ideal_score * 100) %>%
    ungroup()

  category_data <- category_data %>%
    group_by(year) %>%
    mutate(bvt_score = max(ifelse(Tool == "RBVT", score, 0))) %>%
    ungroup()

  category_data <- category_data %>%
    mutate(score_bvt = score / bvt_score * 100)

  # Remove the unneeded columns before writing to CSV
  category_data <- category_data %>%
    select(Tool, year, score, score_ideal, score_bvt)

  # Write the data frame to a CSV file in the "csv" directory
  write.csv(category_data, file = paste0("./csv/answer_", category, "_time.csv"), row.names = FALSE)
}
