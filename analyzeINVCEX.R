library(tidyr)
library(stringr)  # Load the package
library(dplyr)
library(ggplot2)
library(jsonlite)

# Define the years and categories
years <- 2020:2023
categories <- c("global_properties", "reachability", "ltl")
multipliers <- c(5, 32, 32)  # Multipliers for each category respectively
# List of main tools
main_tools <- c("ITS-Tools", "Tapaal", "GreatSPN", "LoLA", "smpt", "enPAC", "ITS-LoLa", "LoLa+red")

# Initialize an empty list to store the data frames
data_list <- list()

dir.create("invcex")

# Loop through all years and categories
for (year in years) {
  for (i in seq_along(categories)) {
    category <- categories[i]
    multiplier <- multipliers[i]
    
    resolution_file_name <- paste0(year, "/", category, "/resolution.csv")
    
    # Read the resolution CSV
    data <- read.csv(resolution_file_name)
    
    # Add year and category as columns
    data$Year <- year
    data$Category <- category
    
    # Count occurrences of each FormulaType
    data <- data %>% count(Year, Category, FormulaType)
    
    models_file_name <- paste0(year, "/models.csv")
    
    # Read the models CSV and count the number of rows (models)
    models_data <- read.csv(models_file_name)
    n_models <- nrow(models_data)
    
    # Calculate the number of UNK formulas
    n_UNK <- n_models * multiplier - sum(data$n)
    
    # Add a row for UNK formulas
    data_UNK <- tibble(Year = year, Category = category, FormulaType = "UNK", n = n_UNK)
    data <- bind_rows(data, data_UNK)
    
    data_list[[length(data_list) + 1]] <- data
  }
}

# Combine all data into one data frame
df <- bind_rows(data_list)

# Calculate proportions
df <- df %>% 
  group_by(Year, Category) %>% 
  mutate(Proportion = n / sum(n))

# Convert FormulaType to a factor and set levels
df$FormulaType <- factor(df$FormulaType, levels = c("UNK", "CEX", "INV"))

# Define the filename
filename <- "invcex/formulas.csv"

# Write the data frame to CSV
write.csv(df, file = filename, row.names = FALSE)

# Create the plot
p <- ggplot(df, aes(x = Year, y = Proportion, fill = FormulaType)) +
  geom_bar(stat = "identity") +
  facet_wrap(~Category) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(x = "Year", y = "Proportion", fill = "FormulaType", title = "Yearly Proportions of Formula Types")

print(p)


# Initialize an empty list to store the data frames
data_list <- list()

# Loop through all years and categories
for (year in years) {
  for (category in categories) {
    resolution_file_name <- paste0(year, "/", category, "/resolution.csv")
    
    # Read the resolution CSV
    resolution_data <- read.csv(resolution_file_name)
    
    # Add year and category as columns
    resolution_data$Year <- year
    resolution_data$Category <- category
    
    tool_file_name <- paste0(year, "/", category, "/tool_index_dict.json")
    
    # Read the JSON
    tool_data <- fromJSON(tool_file_name)
    
    # Initialize a list to store the counts
    tool_counts <- list()
    
    for (tool in names(tool_data)) {
      if (tool %in% main_tools) {
        # Calculate the number of successful results for each tool and FormulaType
        tool_counts[[tool]] <- resolution_data %>%
          filter(Index %in% as.integer(tool_data[[tool]]$answers)) %>%
          count(Year, Category, FormulaType) %>%
          mutate(Tool = tool)
      }
    }
    
    # Combine all tool data into one data frame
    tool_df <- bind_rows(tool_counts)
    
    # Calculate the total number of formulas for each FormulaType
    total_counts <- resolution_data %>% count(Year, Category, FormulaType)
    
    # Merge the tool data with the total counts
    tool_df <- merge(tool_df, total_counts, by = c("Year", "Category", "FormulaType"), suffixes = c("", "_total"))
    
    # Calculate the proportion of successful results
    tool_df$Proportion <- tool_df$n / tool_df$n_total
    
    # Drop rows where n is zero
    tool_df <- tool_df %>% filter(n > 0)
    
    data_list[[length(data_list) + 1]] <- tool_df
  }
}

# Combine all data into one data frame
df <- bind_rows(data_list)

# Define the filename
filename <- "invcex/tools.csv"

# Write the data frame to CSV
write.csv(df, file = filename, row.names = FALSE)


# Loop over each category and plot separately
for (category in unique(df$Category)) {
  df_category <- df %>% filter(Category == category)
  
  p <- ggplot(df_category, aes(x = Tool, y = Proportion, fill = FormulaType)) +
    geom_bar(stat = "identity", position = "dodge") +
    facet_grid(~Year) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
    labs(x = "Tool", y = "Proportion of Successful Results", fill = "FormulaType", 
         title = paste("Performance of Main Tools for", category))
  
  print(p)
}

# with HARD

# Initialize an empty list to store the data frames
data_list <- list()

# Loop through all years and categories
for (year in years) {
  for (category in categories) {
    resolution_file_name <- paste0(year, "/", category, "/resolution.csv")
    
    # Read the resolution CSV
    resolution_data <- read.csv(resolution_file_name)
    
    # Add year, category, and difficulty as columns
    resolution_data$Year <- year
    resolution_data$Category <- category
    resolution_data$Difficulty <- ifelse(resolution_data$Solutions == 1, "Hard", "Other")
    
    tool_file_name <- paste0(year, "/", category, "/tool_index_dict.json")
    
    # Read the JSON
    tool_data <- fromJSON(tool_file_name)
    
    # Initialize a list to store the counts
    tool_counts <- list()
    
    for (tool in names(tool_data)) {
     # if (tool %in% main_tools) {
        # Calculate the number of successful results for each tool, FormulaType and solution difficulty
        tool_counts[[tool]] <- resolution_data %>%
          filter(Index %in% as.integer(tool_data[[tool]]$answers)) %>%
          count(Year, Category, FormulaType, Difficulty) %>%
          mutate(Tool = tool)
    #  }
    }
    
    # Combine all tool data into one data frame
    tool_df <- bind_rows(tool_counts)
    
    # Calculate the total number of formulas for each FormulaType and solution difficulty
    total_counts <- resolution_data %>%
      count(Year, Category, FormulaType, Difficulty)
    
    # Merge the tool data with the total counts
    tool_df <- merge(tool_df, total_counts, by = c("Year", "Category", "FormulaType", "Difficulty"), suffixes = c("", "_total"))
    
    # Calculate the proportion of successful results
    tool_df$Proportion <- tool_df$n / tool_df$n_total
    
    data_list[[length(data_list) + 1]] <- tool_df
  }
}

# Combine all data into one data frame
df <- bind_rows(data_list)

# Define the filename
filename <- "invcex/tools_hard.csv"

# Write the data frame to CSV
write.csv(df, file = filename, row.names = FALSE)


# Loop over each category and plot separately
for (category in unique(df$Category)) {
  df_category <- df %>% filter(Category == category)
  
  p <- ggplot(df_category, aes(x = Tool, y = Proportion, fill = FormulaType, alpha = Difficulty)) +
    geom_bar(stat = "identity", position = "dodge") +
    facet_grid(~Year) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
    scale_alpha_manual(values = c("Hard" = 1, "Other" = 0.5)) +
    labs(x = "Tool", y = "Proportion of Successful Results", fill = "FormulaType", alpha = "Difficulty", 
         title = paste("Performance of Main Tools for", category))
  
  print(p)
}


# Loop over each category and each year, and plot separately
for (category in unique(df$Category)) {
  for (year in unique(df$Year)) {
    df_year_category <- df %>% filter(Category == category & Year == year)
    
    if (nrow(df_year_category) > 0) {  # Check if there is any data for this year and category
      p <- ggplot(df_year_category, aes(x = Tool, y = Proportion, fill = FormulaType, alpha = Difficulty)) +
        geom_bar(stat = "identity", position = "dodge") +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
        scale_alpha_manual(values = c("Hard" = 1, "Other" = 0.5)) +
        labs(x = "Tool", y = "Proportion of Successful Results", fill = "FormulaType", alpha = "Difficulty", 
             title = paste("Performance of Main Tools for", category, "in", year))
      
      print(p)
    }
  }
}




