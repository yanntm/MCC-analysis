# Load the necessary libraries
library(dplyr)
library(tidyr)
library(readr)
library(stringr)  # for str_pad

# Read the data from the CSV files
resolution_df <- read_csv("resolution.csv", col_types = cols(ID = col_character()))
forms_df <- read_delim("forms.csv", delim = " ", col_names = c("Key", "FormulaType"))

# Decrease 'ID' by 1 and pad it with leading zeros
resolution_df <- resolution_df %>%
  mutate(ID = str_pad(as.integer(ID) - 1, width = 2, side = "left", pad = "0"))

# Extract the keys from forms_df by splitting the 'Key' column
forms_df <- forms_df %>%
  separate(Key, into = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID"), sep = "-", remove = FALSE)

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
  left_join(forms_df, by = c("ModelFamily", "ModelType", "ModelInstance", "Examination", "ID")) %>%
  mutate(FormulaType = coalesce(forms_df$FormulaType, resolution_df$FormulaType))

# Drop the 'Key' column
combined_df <- combined_df %>%
  select(-Key)

# Write the resulting dataframe to a new CSV file
write_csv(combined_df, "resolution.csv")
