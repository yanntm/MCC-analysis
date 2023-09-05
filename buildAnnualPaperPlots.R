library(ggplot2)
library(dplyr)

# Define colorblind-friendly palette
palette <- c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7", "#999999", "#000000", "#D7191C")

tools <- c("ITS-Tools", "LoLA", "Tapaal", "smpt", "enPAC", "GreatSPN", "BVT", "tedd")


generate_plot <- function(category) {
  filename <- paste0("csv/answer_", category, "_time.csv")
  
  # Read data
  data <- read.csv(filename)
  
  # Filter data
  data <- data %>%
    filter(year >= 2018, Tool %in% tools)
  
  # Map tools to colors and shapes
  tool_colors <- setNames(palette[1:length(tools)], tools)
  tool_shapes <- setNames(seq_along(tools), tools)  # Use sequence along tools as shapes
  
  # Generate plot
  p <- ggplot(data, aes(x = year, y = answer_ideal, color = Tool, shape = Tool)) +
    geom_line(size = 1.5) +
    geom_point(size = 6) +
    scale_y_continuous(breaks = seq(0, 100, by = 10), labels = scales::percent_format(scale = 1)) +  # Set y-axis breaks every 10%
    scale_color_manual(values = tool_colors) +
    scale_shape_manual(values = tool_shapes) +  # Set shapes
    labs(x = NULL, y = NULL, title = NULL) + # Remove labels and title
    theme_minimal() +
    theme(
      legend.position = "top",  # Move legend to top
      legend.box = "horizontal",  # Make legend horizontal
      panel.grid.minor = element_blank(),  # Remove minor grid lines
      axis.title = element_text(size = 16, face = "bold"),  # Increase size & make axis title bold
      axis.text = element_text(size = 16, face = "bold"),   # Increase size & make axis text bold
      legend.title = element_text(size = 16, face = "bold"),  # Increase size & make legend title bold
      legend.text = element_text(size = 16, face = "bold")    # Increase size & make legend text bold
    )
  
  # Save plot
  output_filename <- paste0(category, "_plot.pdf")
  ggsave(filename = output_filename, plot = p, device = "pdf", width = 8, height = 7)
}



categories <- c("global_properties", "reachability", "upper_bounds", "ltl", "ctl", "state_space")
for (category in categories) {
  generate_plot(category)
}
