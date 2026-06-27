library(ggplot2)
library(dplyr)

# a custom palette that "looks good" (TM)
palette <- c("#3b528b", "#5ec962",  "#f7941d", "#b4192e", "#911a7c", "#CC79A7", "#0daca7", "#56B4E9")

tools <- c("ITS-Tools", "LoLA", "Tapaal", "smpt", "enPAC", "GreatSPN", "BVT", "tedd")

# Map tools to colors and shapes
tool_colors <- setNames(palette[1:length(tools)], tools)
tool_shapes <- setNames(seq_along(tools), tools)  # Use sequence along tools as shapes


# Extract legend
extract_legend <- function(plot) {
  tmp <- ggplot_gtable(ggplot_build(plot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
# Generate dummy plot with all tools
dummy_data <- data.frame(year = rep(2018, length(tools)), answer_ideal = seq(1, length(tools)), Tool = tools)
# Generate dummy plot with all tools
dummy_plot <- ggplot(dummy_data, aes(x = year, y = answer_ideal, color = Tool, shape = Tool)) +
  geom_point(size = 6, aes(stroke = 2)) +  # Increase the stroke for bolder shapes
  scale_color_manual(values = tool_colors) +
  scale_shape_manual(values = tool_shapes) +
  guides(
    color = guide_legend(title = NULL, override.aes = list(stroke = 2)),  # Increase the stroke for bolder shapes in legend
    shape = guide_legend(title = NULL)
  ) +
  theme(
    legend.title = element_blank(),
    legend.position = "top",
    legend.direction = "horizontal",  # Make legend horizontal
    legend.text = element_text(size = 30, face = "bold"),  # Size 30, bold font
    legend.key.size = unit(2, 'cm'),  # Adjust the size of the legend key for better visibility
    legend.key = element_rect(fill = "white", colour = NA)  # Set legend key background to white and remove border
  )


# Extract the legend from the dummy plot
legend_grob <- extract_legend(dummy_plot)

# Save the legend as a PDF with adjusted width and height
ggsave("legend.pdf", legend_grob, device = "pdf", width = 10, height = 2)

generate_plot <- function(category) {
  filename <- paste0("csv/answer_", category, "_time.csv")
  
  # Read data
  data <- read.csv(filename)
  
  # Filter data
  data <- data %>%
    filter(year >= 2018, Tool %in% tools)
  
  
  
  # Generate plot
  p <- ggplot(data, aes(x = year, y = answer_ideal, color = Tool, shape = Tool)) +
    geom_line(size = 1.5) +
    geom_point(size = 6,aes(stroke = 2)) +
    scale_y_continuous(breaks = seq(0, 100, by = 10), labels = scales::percent_format(scale = 1)) +  # Set y-axis breaks every 10%
    scale_color_manual(values = tool_colors) +
    scale_shape_manual(values = tool_shapes) +  # Set shapes
    labs(x = NULL, y = NULL, title = NULL) + # Remove labels and title
    theme_minimal() +
    theme(
      axis.text.x = element_text(size = 30, face = "bold", angle = 45, hjust = 1), # x with an angle
      legend.box = "horizontal",  # Make legend horizontal
      panel.grid.minor = element_blank(),  # Remove minor grid lines
      axis.title = element_text(size = 30, face = "bold"),  # Increase size & make axis title bold
      axis.text = element_text(size = 30, face = "bold"),   # Increase size & make axis text bold
      legend.title = element_text(size = 30, face = "bold"),  # Increase size & make legend title bold
      legend.text = element_text(size = 30, face = "bold"),    # Increase size & make legend text bold
#      legend.position = "top",  # Move legend to top
      legend.position = "none" # discard the legend !
    )
  
  # Save plot
  output_filename <- paste0(category, "_plot.pdf")
  ggsave(filename = output_filename, plot = p, device = "pdf", width = 8, height = 7)
}



categories <- c("global_properties", "reachability", "upper_bounds", "ltl", "ctl", "state_space")
for (category in categories) {
  generate_plot(category)
}
