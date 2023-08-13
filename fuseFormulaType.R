# Load the necessary libraries
library(dplyr)
library(tidyr)
library(readr)
library(stringr)  # for str_pad


# Initialize forms_df and nupn_df with required columns
forms_df <- data.frame(Key = character(),
                       ModelFamily = character(), 
                       ModelType = character(), 
                       ModelInstance = character(), 
                       Examination = character(),
                       ID = character(), 
                       FormulaType = character(),
                       stringsAsFactors = FALSE)

nupn_df <- data.frame(ModelFamily = character(), 
                      ModelType = character(), 
                      ModelInstance = character(), 
                      Nupn = character(),
                      stringsAsFactors = FALSE)


# Check if forms.csv exists in the current working directory
if (file.exists("./iscex.csv")) {
  forms_df <- read_delim("./iscex.csv", delim = " ", col_names = c("Key", "FormulaType"))
  # Extract the keys from forms_df by splitting the 'Key' column
  forms_df <- forms_df %>%
    separate(Key, into = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID"), sep = "-", remove = FALSE)
}

# Check if nupn.csv exists in the current working directory
if (file.exists("./nupn.csv")) {
  nupn_df <- read_csv("./nupn.csv", col_types = cols())
  nupn_df <- nupn_df %>%
    separate(model, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-", remove = FALSE) %>%
    mutate(Nupn = case_when(
      isNUPN == "FALSE" & isGenNUPN == "FALSE" ~ "NONE",
      isSafe == "TRUE" & isNUPN == "FALSE" & isGenNUPN == "TRUE" ~ "GEN",
      isSafe == "TRUE" & isNUPN == "TRUE" & isGenNUPN == "FALSE" ~ "NUPN",
      TRUE ~ "ERROR"  # default case for unexpected combinations
    ))
}

# List of folders to process
folders <- c("ctl", "ltl", "reachability", "state_space", "upper_bounds", "global_properties")

# Process each folder
for (folder in folders) {
  
  # Construct the full file path for the resolution.csv in the current folder
  resolution_file_path <- paste0(folder, "/resolution.csv")
  
  # Read the data from the CSV file
  resolution_df <- read_csv(resolution_file_path, col_types = cols(ID = col_character()))
  
  # Apply the conditional rules to resolution_df
  resolution_df <- resolution_df %>%
    mutate(FormulaType = case_when(
      grepl("LTL", Examination) & Consensus == "TRUE" ~ "INV",
      grepl("LTL", Examination) & Consensus == "FALSE" ~ "CEX",
      Examination == "ReachabilityDeadlock" & Consensus == "TRUE" ~ "CEX",
      Examination == "ReachabilityDeadlock" & Consensus == "FALSE" ~ "INV",
      Examination == "OneSafe" & Consensus == "TRUE" ~ "INV",
      Examination == "OneSafe" & Consensus == "FALSE" ~ "CEX",
      Examination == "StableMarking" & Consensus == "TRUE" ~ "INV",
      Examination == "StableMarking" & Consensus == "FALSE" ~ "CEX",
      Examination == "QuasiLiveness" & Consensus == "TRUE" ~ "INV",
      Examination == "QuasiLiveness" & Consensus == "FALSE" ~ "CEX",
      Examination == "Liveness" & Consensus == "TRUE" ~ "INV",
      Examination == "Liveness" & Consensus == "FALSE" ~ "CEX",
      TRUE ~ "UNKNOWN"  # default case
    ))
  
  # Join the two dataframes. Use left join to keep all records in resolution_df
  combined_df <- resolution_df %>%
    left_join(forms_df, by = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID")) %>%
    left_join(nupn_df, by = c("ModelFamily", "ModelType", "ModelInstance"))
  
  # Fill the NA values in FormulaType and Nupn columns
  combined_df <- combined_df %>%
    mutate(
      FormulaType = coalesce(.$FormulaType.y, .$FormulaType.x),
      Nupn = coalesce(.$Nupn, "NONE")
    )
  
  # Drop the 'Key', 'FormulaType.x', 'FormulaType.y', 'isSafe', 'isNUPN' and 'isGenNUPN' columns
  combined_df <- combined_df %>%
    select(-Key, -FormulaType.x, -FormulaType.y, -isSafe, -isNUPN, -isGenNUPN, -model)
  
  # Write the resulting dataframe to a new CSV file
  write_csv(combined_df, resolution_file_path)
}
