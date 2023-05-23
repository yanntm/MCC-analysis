# Load the necessary libraries
library(dplyr)
library(tidyr)
library(readr)
library(stringr)  # for str_pad


# Initialize forms_df as an empty data frame
forms_df <- data.frame()

# Check if forms.csv exists in the current working directory
if (file.exists("./iscex.csv")) {
  forms_df <- read_delim("./iscex.csv", delim = " ", col_names = c("Key", "FormulaType"))
  # Extract the keys from forms_df by splitting the 'Key' column
  forms_df <- forms_df %>%
    separate(Key, into = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID"), sep = "-", remove = FALSE)
}

# List of folders to process
folders <- c("ctl", "ltl", "reachability", "state_space", "upper_bounds", "global_properties")

# Process each folder
for (folder in folders) {
  
  # Construct the full file path for the resolution.csv in the current folder
  resolution_file_path <- paste0(folder, "/resolution.csv")
  
  # Read the data from the CSV file
  resolution_df <- read_csv(resolution_file_path, col_types = cols(ID = col_character()))
  
  # Decrease 'ID' by 1 and pad it with leading zeros
  resolution_df <- resolution_df %>%
    mutate(ID = str_pad(as.integer(ID) - 1, width = 2, side = "left", pad = "0"))
  
  # Apply the conditional rules to resolution_df
  resolution_df <- resolution_df %>%
    mutate(FormulaType = case_when(
      grepl("LTL", Examination) & Consensus == "T" ~ "INV",
      grepl("LTL", Examination) & Consensus == "F" ~ "CEX",
      Examination == "ReachabilityDeadlock" & Consensus == "T" ~ "CEX",
      Examination == "ReachabilityDeadlock" & Consensus == "F" ~ "INV",
      Examination == "OneSafe" & Consensus == "T" ~ "INV",
      Examination == "OneSafe" & Consensus == "F" ~ "CEX",
      Examination == "StableMarking" & Consensus == "T" ~ "INV",
      Examination == "StableMarking" & Consensus == "F" ~ "CEX",
      Examination == "QuasiLiveness" & Consensus == "T" ~ "INV",
      Examination == "QuasiLiveness" & Consensus == "F" ~ "CEX",
      Examination == "Liveness" & Consensus == "T" ~ "INV",
      Examination == "Liveness" & Consensus == "F" ~ "CEX",
      TRUE ~ "UNKNOWN"  # default case
    ))
  
  # Join the two dataframes. Use left join to keep all records in resolution_df
  combined_df <- resolution_df %>%
    left_join(forms_df, by = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID"))
  
  # Fill the NA values in FormulaType column
  combined_df <- combined_df %>%
    mutate(FormulaType = coalesce(.$FormulaType.y, .$FormulaType.x))
  
  # Drop the 'Key' and 'FormulaType.x' columns
  combined_df <- combined_df %>%
    select(-Key, -FormulaType.x, -FormulaType.y)
  
  # Write the resulting dataframe to a new CSV file
  write_csv(combined_df, resolution_file_path)
}
