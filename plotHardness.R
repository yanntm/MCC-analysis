library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)



# Define a function to create a plot for given data
create_plot <- function(data, name){
  
  # Calculate the sorting column
  data <- data %>%
    mutate(
      sort_value = 1e9 * (count_solutions_1 + count_solutions_2 + count_solutions_3) / (count_solutions_0 + count_solutions_1 + count_solutions_2 + count_solutions_3) +
        1e6 * (count_solutions_3 + count_solutions_2) / (count_solutions_0 + count_solutions_1 + count_solutions_2 + count_solutions_3) +
        1e3 * count_solutions_3 / (count_solutions_0 + count_solutions_1 + count_solutions_2 + count_solutions_3) +
        count_solutions_1 / (count_solutions_0 + count_solutions_1 + count_solutions_2 + count_solutions_3)
    )
  
  # Convert the data to long format
  data_long <- data %>%
    tidyr::pivot_longer(cols = starts_with("count_solutions"),
                        names_to = "solution",
                        values_to = "count")
  
  # Create a factor column for ordering the solutions in the legend
  data_long$solution <- factor(data_long$solution, 
                               levels = c("count_solutions_0", 
                                          "count_solutions_1", 
                                          "count_solutions_2", 
                                          "count_solutions_3"),
                               labels = c("unsolved", 
                                          "hard (1 tool only)", 
                                          "medium (2 tools)", 
                                          "easy (3 or more tools)"))
  
  # Create a color palette to match your original colors
  colors <- c("unsolved" = "white", 
              "hard (1 tool only)" = "red", 
              "medium (2 tools)" = "orange", 
              "easy (3 or more tools)" = "green")
  
  # Create the plot
  plot <- ggplot(data_long, 
                 aes(y = reorder(paste(ModelFamily, ModelType, sep = "-"), -sort_value), 
                     x = count/total_solutions, 
                     fill = solution)) +
    geom_bar(stat = "identity", width=0.6) +
    scale_x_continuous(labels = scales::percent) +  # Use percentage labels for the x-axis
    scale_fill_manual(values = colors) +
    labs(title = paste0(name, " Model Difficulty"),
         x = "Percentage of queries solved",
         y = "Model (Family-Type)",
         fill = "Solution Count") +
    theme_minimal() 
  
  # Save the plot
  ggsave(filename = paste0(name, "ModelEase.png"), plot = plot, width = 8, height = 12)
}

# Load the ModelDescriptions.csv data
model_desc <- read_csv("ModelDescriptions.csv")

# Parse the "Input" column into the "ModelFamily", "ModelType", "ModelInstance" columns
model_desc <- model_desc %>% 
  separate(Model, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-", remove = FALSE)

# Define ideal scores
ideal_scores <- c('ctl' = 32, 'global_properties' = 5, 'ltl' = 32, 'reachability' = 32, 'state_space' = 4, 'upper_bounds' = 16)

# Aggregate the model descriptions by ModelFamily, ModelType, and ModelInstance
model_desc_agg <- model_desc %>%
  group_by(ModelFamily, ModelType, ModelInstance) %>%
  summarise(count_instances = n())

# Now aggregate again by ModelFamily and ModelType to get the total counts
model_desc_agg <- model_desc_agg %>%
  group_by(ModelFamily, ModelType) %>%
  summarise(total_instances = sum(count_instances))

# Initialize overall_data as a data frame with the necessary columns
overall_data <- model_desc_agg %>%
  mutate(total_solutions = 0, total_IdealScore = 0, 
         count_solutions_0 = 0, count_solutions_1 = 0, 
         count_solutions_2 = 0, count_solutions_3 = 0)

# Get the list of folders that contain "resolution.csv"
directories <- list.dirs(path = ".", recursive = FALSE)

# For each directory (i.e., examination category)
for(dir in directories){
  
  # Path to the resolution.csv file in this directory
  resolution_path <- file.path(dir, "resolution.csv")
  
  # Only proceed if resolution.csv exists in this directory
  if(file.exists(resolution_path)){
    
    # Extract the examination name from the directory path
    examination <- basename(dir)
    
    # Get the ideal score for this examination
    ideal_score <- ideal_scores[[examination]]
    
    # Load resolution data
    resolution <- read_csv(resolution_path)
    
    # Calculate counts of solutions
    resolution_counts <- resolution %>%
      group_by(ModelFamily, ModelType, Solutions) %>%
      summarise(count_solutions = n()) %>%
      spread(key = Solutions, value = count_solutions, fill = 0)
    
    # Join the model descriptions with the resolution data, compute IdealScore and EaseScore
    examination_data <- left_join(model_desc_agg, resolution_counts, by = c("ModelFamily", "ModelType")) %>%
      replace_na(list(`0` = 0, `1` = 0, `2` = 0, `3` = 0)) %>%
      mutate(IdealScore = total_instances * ideal_score,
             count_solutions_0 = IdealScore - (`1` + `2` + `3`),
             count_solutions_1 = `1`,
             count_solutions_2 = `2`,
             count_solutions_3 = `3`,
             total_solutions = IdealScore) %>%  # Compute total_solutions here
      select(ModelFamily, ModelType, total_instances, IdealScore, total_solutions, 
             count_solutions_0, count_solutions_1, count_solutions_2, count_solutions_3)
    
    # Add examination_data to overall_data
    overall_data <- bind_rows(overall_data, examination_data)
    
    # Create a plot for this examination data
    create_plot(examination_data, examination)
  }
}

# Calculate overall ease score
overall_data <- overall_data %>%
  group_by(ModelFamily, ModelType, total_instances) %>%
  summarise(total_solutions = sum(total_solutions, na.rm = TRUE),
            total_IdealScore = sum(IdealScore, na.rm = TRUE),
            count_solutions_0 = sum(count_solutions_0, na.rm = TRUE),
            count_solutions_1 = sum(count_solutions_1, na.rm = TRUE),
            count_solutions_2 = sum(count_solutions_2, na.rm = TRUE),
            count_solutions_3 = sum(count_solutions_3, na.rm = TRUE)) %>%
  mutate(OverallEaseScore = (count_solutions_1 + count_solutions_2 + count_solutions_3) / total_IdealScore * 100) %>%
  ungroup()

# Create a plot for the overall data
create_plot(overall_data, "Overall")


