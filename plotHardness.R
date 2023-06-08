library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

# Load the ModelDescriptions.csv data
model_desc <- read_csv("ModelDescriptions.csv")

# Parse the "Model" column into "ModelFamily", "ModelType", "ModelInstance" columns
model_desc <- model_desc %>%
  separate(Model, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-", remove = FALSE)

# Define ideal scores
ideal_scores <- c('ctl' = 32, 'global_properties' = 5, 'ltl' = 32, 'reachability' = 32, 'state_space' = 4, 'upper_bounds' = 16)

# Aggregate the model descriptions by ModelFamily, ModelType, and ModelInstance
model_desc_agg <- model_desc %>%
  group_by(ModelFamily, ModelType, ModelInstance) %>%
  summarise(count_instances = n(), .groups = "drop") %>%
  group_by(ModelFamily, ModelType) %>%
  summarise(total_instances = sum(count_instances), .groups = "drop")

# Get the list of directories that contain "resolution.csv"
directories <- list.dirs(path = ".", recursive = FALSE)

# Create an empty data frame to store the overall EaseScore
# Initialize overall_data as a data frame with the necessary columns
overall_data <- model_desc_agg %>%
  mutate(total_solutions = 0, total_IdealScore = 0)

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
    
    # Aggregate resolution data by ModelFamily and ModelType and calculate the sum of solutions
    resolution_agg <- resolution %>%
      group_by(ModelFamily, ModelType) %>%
      summarise(count_solutions = sum(Solutions), .groups = "drop")
    
    # Join the model descriptions with the resolution data, compute IdealScore and EaseScore
    examination_data <- left_join(model_desc_agg, resolution_agg, by = c("ModelFamily", "ModelType")) %>%
      replace_na(list(count_solutions = 0)) %>%
      mutate(IdealScore = total_instances * ideal_score,
             EaseScore = count_solutions / IdealScore * 100)  # Express EaseScore as a percentage
    
    # Update overall_data by accumulating the solutions and ideal scores
    # Add examination_data to overall_data
    overall_data <- bind_rows(overall_data, examination_data)
    
    # Create the bar plot
    plot <- ggplot(examination_data, aes(y = reorder(paste(ModelFamily, ModelType, sep = "-"), -EaseScore), x = EaseScore)) +
      geom_bar(stat = "identity") +
      labs(title = paste("Model Ease -", examination),  # Add the directory/examination name in the title
           y = "Model (Family-Type)",
           x = "Ease Score (%)") +
      theme_minimal() +
      theme(axis.text.y = element_text(hjust = 1))  # Rotate y-axis labels
    
    # Save the plot
    ggsave(filename = file.path(dir, "ModelEase.png"), plot = plot, width = 10, height = 8)
  }
}


# Calculate total solutions and ideal scores by 'ModelFamily' and 'ModelType'
overall_data <- overall_data %>%
  group_by(ModelFamily, ModelType, total_instances) %>%
  summarise(total_solutions = sum(count_solutions, na.rm = TRUE),
            total_IdealScore = sum(IdealScore, na.rm = TRUE)) %>%
  mutate(OverallEaseScore = total_solutions / total_IdealScore * 100)  # Compute the overall ease score

# Create the overall ease score bar plot
plot <- ggplot(overall_data, aes(y = reorder(paste(ModelFamily, ModelType, sep = "-"), -OverallEaseScore), x = OverallEaseScore)) +
  geom_bar(stat = "identity") +
  labs(title = "Overall Model Ease",
       y = "Model (Family-Type)",
       x = "Overall Ease Score (%)") +
  theme_minimal() +
  theme(axis.text.x = element_text(hjust = 1))  # Rotate x-axis labels

# Save the plot
ggsave(filename = "OverallModelEase.png", plot = plot, width = 10, height = 8)