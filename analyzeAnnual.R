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

# Curate the tool names
combined_data$tool <- case_when(
  combined_data$tool %in% c("MARCIE", "Marcie") ~ "Marcie",
  combined_data$tool %in% c("Smart", "smart") ~ "Smart",
  combined_data$tool %in% c("TINA.tedd", "tedd", "tedd-c") ~ "tedd",
  combined_data$tool == "LoLa" ~ "LoLA",
  combined_data$tool == "LoLa+red" ~ "ITS-LoLa",
  combined_data$tool == "ITS-Tools.L" ~ "ITS-Tools.M",
  combined_data$tool == "Tapaal(SEQ)" ~ "Tapaal",
  grepl("^RBVT-", combined_data$tool) ~ "RBVT",
  grepl("^BVT-", combined_data$tool) ~ "BVT",
  combined_data$tool %in% c("2018-Gold", "2019-Gold", "2020-gold", "2021-gold", "2022-gold") ~ "LastYear-gold",
  TRUE ~ combined_data$tool
)

# Get the column names for examinations
score_cols <- grep("^score_", colnames(combined_data), value = TRUE)

# Replace 0 scores with NA (meaning the tool did not participate)
combined_data[score_cols] <- lapply(combined_data[score_cols], function(x) replace(x, x == 0, NA))

# Create a plot for each examination
# Loop over score_XX columns
for (score_col in score_cols) {
  # Compute the name of the normalized score column
  norm_score_col <- paste0("norm_", score_col)
  
  # Compute normalized scores for this examination
  combined_data2 <- combined_data %>%
    group_by(year) %>%
    mutate(ideal_score = max(ifelse(tool == "Ideal Tool", .data[[score_col]], 0))) %>%
    mutate({{norm_score_col}} := .data[[score_col]] / ideal_score * 100) %>%
    ungroup()
  

  # Filter out tools with NA values for norm_score_col
  combined_data2 <- combined_data2 %>% 
    filter(!is.na(.data[[norm_score_col]]))
  
  
  # Count the number of years each tool participated in this examination
  tool_counts <- combined_data2 %>% 
    filter(!is.na(.data[[norm_score_col]])) %>% 
    group_by(tool) %>%
    summarise(n = n_distinct(year))
  
  # Add points for all tools
  p <- ggplot(combined_data2, aes_string(x = "year", y = norm_score_col, color = "tool")) +
    geom_point() +
    scale_x_continuous(breaks = unique(combined_data$year)) +
    labs(title = paste(score_col, "Score Over Time"), x = "Year", y = "Score (% of Ideal Tool)") +
    theme(legend.position = "bottom") +
    guides(color = guide_legend(ncol = 3, title = "Tool"))
  
  # Add lines for tools that have participated more than once
  for (tool in tool_counts$tool[tool_counts$n > 1]) {
    p <- p + geom_line(data = combined_data2[combined_data2$tool == tool, ], aes_string(x = "year", y = norm_score_col, color = "tool"))
  }
  
  # Save the plot as a PNG in the "plots" directory
  ggsave(filename = paste0("./", gsub(" ", "_", score_col), "_time.png"), plot = p, width = 10, height = 7, dpi = 300)
  
}


# do it again but for building the CSV
# Create a plot for each examination
# Loop over score_XX columns
for (score_col in score_cols) {
  # Compute the name of the normalized score column
  norm_score_col <- paste0("norm_", score_col)
  
  # Compute normalized scores for this examination
  combined_data2 <- combined_data %>%
    group_by(year) %>%
    mutate(ideal_score = max(ifelse(tool == "Ideal Tool", .data[[score_col]], 0))) %>%
    mutate(score_ideal = .data[[score_col]] / ideal_score * 100) %>%
    ungroup()

  # Compute the BVT score for each year
  combined_data2 <- combined_data2 %>%
    group_by(year) %>%
    mutate(bvt_score = max(ifelse(tool == "RBVT", .data[[score_col]], 0))) %>%
    ungroup()

  # Compute the percentage of the BVT score
  combined_data2 <- combined_data2 %>%
    mutate(score_bvt = .data[[score_col]] / bvt_score * 100)

  # Filter out tools with NA values for score_ideal and score_bvt
  combined_data2 <- combined_data2 %>%
    filter(!is.na(score_ideal), !is.na(score_bvt)) %>%
    rename(score = score_col)
  
  # Select only the columns we're interested in
  combined_data2 <- combined_data2 %>%
    select(tool, year, score, score_ideal, score_bvt)
  
  # Write the data frame to a CSV file in the "csv" directory
  write.csv(combined_data2, file = paste0("./csv/", gsub(" ", "_", score_col), "_time.csv"), row.names = FALSE)
}



