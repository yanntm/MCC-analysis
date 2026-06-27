library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)



# Extract legend
extract_legend <- function(plot) {
  tmp <- ggplot_gtable(ggplot_build(plot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}

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
  
  # Calculate overall ease score
  data2 <- data %>%
    group_by(ModelFamily, ModelType, total_instances) %>%
    summarise(total_solutions = sum(total_solutions, na.rm = TRUE),
              total_IdealScore = sum(IdealScore, na.rm = TRUE),
              count_solutions_0 = sum(count_solutions_0, na.rm = TRUE),
              count_solutions_1 = sum(count_solutions_1, na.rm = TRUE),
              count_solutions_2 = sum(count_solutions_2, na.rm = TRUE),
              count_solutions_3 = sum(count_solutions_3, na.rm = TRUE)) %>%
    mutate(OverallEaseScore = (count_solutions_1 + count_solutions_2 + count_solutions_3) / total_IdealScore * 100) %>%
    ungroup()
  
  
  print(paste("Examination :", name))
  # print (data2)
  
  # Number of solved models
  solved_models <- data2 %>% filter(OverallEaseScore == 100)
  num_solved_models <- nrow(solved_models)
  print(paste("Number of solved models:", num_solved_models))
  
  # Number of easy models
  easy_models <- data2 %>% filter(count_solutions_3 == total_IdealScore)
  num_easy_models <- nrow(easy_models)
  print(paste("Number of easy models:", num_easy_models))
  
  # 15 hardest models
  hardest_models <- data2 %>% arrange(OverallEaseScore) %>% head(15)
  print("15 hardest models:")
  print(hardest_models[, c("ModelFamily", "ModelType", "OverallEaseScore")])
  
  
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
  
  # a custom palette that "looks good" (TM)
  palette <- c("#3b528b", "#5ec962",  "#f7941d", "#b4192e", "#911a7c", "#CC79A7", "#0daca7", "#56B4E9")
  
  # Create a color-blind/BW friendly palette
  # Incorporate the custom palette into your other plot's colors
  colors <- c("unsolved" = "white", 
              "hard (1 tool only)" = palette[4], 
              "medium (2 tools)" = palette[3], 
              "easy (3 or more tools)" = palette[2])
  

  plot <- ggplot(data_long, 
                 aes(y = reorder(paste(ModelFamily, ModelType, sep = "-"), -sort_value), 
                     x = count/total_solutions, 
                     fill = solution)) +
    geom_bar(stat = "identity", width=0.8) +
    scale_x_continuous(labels = scales::percent) +
    scale_fill_manual(values = colors) +
    labs(title = NULL, x = NULL, y = NULL, fill = NULL) +
    theme_minimal() +
    theme(
      legend.position = "none",  # Remove the legend
      axis.text.y = element_blank(),
      panel.grid.minor.y = element_blank(),
      panel.grid.major.y = element_blank(),
      axis.title = element_text(size = 28, face = "bold"),
      axis.text = element_text(size = 28, face = "bold"),
      panel.grid.major.x = element_line(size = 1.5, color = "black"),  # Emphasize the vertical lines on x-axis
    )
  ggsave(filename = paste0(name, "_ModelEase.pdf"), plot = plot, width = 8, height = 7, device = "pdf")

  
  categories <- c("unsolved", "hard (1 tool only)", "medium (2 tools)", "easy (3 or more tools)")
  
  # Dummy data to generate only the legend
  dummy_data <- data.frame(solution = c("unsolved", "hard (1 tool only)", "medium (2 tools)", "easy (3 or more tools)"), 
                           count = c(1,1,1,1))
  
  # Ensure the solution variable is a factor with a specific order
  dummy_data$solution <- factor(dummy_data$solution, levels = categories)
  
  # Create the dummy scatter plot
  dummy_plot <- ggplot(dummy_data, aes(x = count, y = count, color = solution)) +
    geom_point(aes(fill = solution), stroke=1, size = 10) + 
    scale_color_manual(values = colors) +
    theme(
      legend.title = element_blank(),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.text = element_text(size = 30, face = "bold"),
      legend.key.size = unit(2, 'cm')
#      legend.key = element_rect(fill = "white", colour = NA)
    )
  
  # Extract the legend
  legend_grob <- extract_legend(dummy_plot)
  
  # Save the legend as a PDF
  ggsave("legendEase.pdf", legend_grob, device = "pdf", width = 18, height = 1.5)
  
}

# Load the ModelDescriptions.csv data
model_desc <- read_csv("models.csv")
# Filter out rows where 'Input' starts with "S_"
# these are the "Stripped" models we had in earlier editions of the MCC.
model_desc <- model_desc[!grepl("^S_", model_desc$ModelFamily),] 

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

# NOTE: the "Overall" aggregate plot is intentionally omitted for the paper.
# (overall_data carries total_IdealScore, not IdealScore, so create_plot()'s
# per-examination data2 aggregation does not apply to it.)


