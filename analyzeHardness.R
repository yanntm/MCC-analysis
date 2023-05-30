library(dplyr)
library(tidyr)
library(readr)

# Load original data frame
df <- read_csv("ModelDescriptions.csv")

# Rename 'Model' column to 'ModelKey'
df <- df %>% rename(ModelKey = Model)

# List of years from 2016 to 2023
years <- as.character(2016:2023)

# Initialize empty list to hold all resolution data
resolution_data <- list()

# Iterate over the years
for(year in years){
  # Get all directories containing resolution.csv in the given year
  directories <- list.files(path = paste0("../", year), pattern = "resolution.csv", recursive = TRUE, full.names = TRUE)

  # For each directory (i.e., examination category)
  for(dir in directories){
    # Extract examination name from the directory path
    examination <- strsplit(dir, "/")[[1]][3]
    
    # Load resolution data and create 'ModelKey' field
    resolution <- read_csv(dir)
    resolution <- resolution %>% mutate(ModelKey = paste(ModelFamily, ModelType, ModelInstance, sep = "-"))
    
    # Join resolution data with original df, count the number of resolved instances per model
    joined <- df %>%
      left_join(resolution, by = "ModelKey") %>%
      group_by(ModelKey) %>%
      summarise(count = n(), .groups = "drop") %>%
      replace_na(list(count = 0)) %>%
      rename(!!paste0(examination, "BVT", year) := count)
    
    # Load model data and create 'ModelKey' field
    models <- read_csv(paste0("../", year, "/models.csv"))
    models <- models %>% mutate(ModelKey = paste(ModelFamily, ModelType, ModelInstance, sep = "-"))
    
    # Flag if model exists in the year's models.csv
    joined <- joined %>% 
      mutate(ExistsModels = ifelse(ModelKey %in% models$ModelKey, 1, 0))
      
    # Flag if model exists in resolution.csv
    joined <- joined %>% 
      mutate(ExistsResolution = ifelse(ModelKey %in% resolution$ModelKey, 1, 0))
    
    
    # Replace counts with 0 for models not existing in resolution.csv
    joined <- joined %>% 
      mutate_at(vars(ends_with(paste0("BVT", year))), list(~if_else(ExistsResolution == 0, 0, .))) %>%
      mutate_at(vars(ends_with(paste0("BVT", year))), list(~if_else(ExistsModels == 0, NA_real_, .))) %>%
      select(-ExistsModels, -ExistsResolution)

    # Append joined data to the list
    resolution_data[[length(resolution_data) + 1]] <- joined
  }
}

# Join all resolution data with the original df
for(data in resolution_data){
  df <- left_join(df, data, by = "ModelKey")
}

# Split 'ModelKey' column into 'ModelFamily', 'ModelType', 'ModelInstance'
df <- df %>% 
  separate(ModelKey, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-")

# Save the updated df to a CSV file
write_csv(df, "ModelHardness.csv")
