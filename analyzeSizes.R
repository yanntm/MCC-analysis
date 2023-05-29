# Import necessary libraries
library(ggplot2)
library(readr)
library(scales)
library(tidyr)
library(dplyr)

# Function to create density histogram plot
create_density_plot <- function(df, column_name, model_type=NULL) {
  if (!is.null(model_type)) {
    df <- df %>% filter(ModelType == model_type)
  } else {
    model_type <- "All"
  }
  
  p <- ggplot(df, aes_string(x = column_name)) +
    geom_histogram(aes(y = ..density..), bins = 30, fill = "blue") +
    geom_density(alpha = .2, fill = "#FF6666") +  # Add density plot
    scale_x_log10(breaks = c(1,10,100,1e3,1e4,1e5,1e6),  # Manual breaks
                  labels = c("1", "10", 100 ,expression(10^3), expression(10^4),
                             expression(10^5), expression(10^6))) +  # Manual labels
    theme_minimal() +
    ggtitle(paste0("Histogram with Density Plot of ", column_name, " (Log Scale) for ",model_type," Models")) +
    xlab(paste0("Number of ", column_name, " (Log Scale)")) +
    ylab("Density")
  
  # Save the plot to a PNG file
  ggsave(filename = paste0(column_name, "_density_plot_", model_type, ".png"), plot = p, dpi = 300)
}

# Function to create box plot
create_box_plot <- function(df, model_type=NULL) {
  if (!is.null(model_type)) {
    df <- df %>% filter(ModelType == model_type)
  } else {
    model_type <- "All"
  }
  
  df_long <- pivot_longer(df, cols = c(Places, Transitions, Arcs), names_to = "Metric", values_to = "Count")
  
  p <- ggplot(df_long, aes(x = Metric, y = Count)) +
    geom_boxplot() +
    scale_y_log10(breaks = c(1,10,100,1e3,1e4,1e5,1e6,1e7),  # Manual breaks
                  labels = c("1", "10", "100" ,expression(10^3), expression(10^4),
                             expression(10^5), expression(10^6), expression(10^7))) +  # Manual labels
    theme_minimal() +
    ggtitle(paste0("Box Plot of Places, Transitions, and Arcs (Log Scale) for ",model_type," Models")) +
    xlab("Metric") +
    ylab("Count (Log Scale)")
  
  ggsave(filename = paste0("box_plot_", model_type, ".png"), plot = p, dpi = 300)
}

# Load the data
data <- read_csv("ModelDescriptions.csv")

# Split Model column into ModelFamily, ModelType, ModelInstance
data <- data %>% 
  separate(Model, into = c("ModelFamily", "ModelType", "ModelInstance"), sep = "-")

# Invoke the function for Places, Transitions, and Arcs
create_density_plot(data, "Places")
create_density_plot(data, "Transitions")
create_density_plot(data, "Arcs")

# Invoke the function for Places, Transitions, and Arcs for each ModelType separately
create_density_plot(data, "Places", "COL")
create_density_plot(data, "Transitions", "COL")
create_density_plot(data, "Arcs", "COL")

create_density_plot(data, "Places", "PT")
create_density_plot(data, "Transitions", "PT")
create_density_plot(data, "Arcs", "PT")

# Create box plot for all data
create_box_plot(data)

# Create box plot for each ModelType separately
create_box_plot(data, "COL")
create_box_plot(data, "PT")
