import os
import jinja2
import glob

# Get the list of all PNG images in the current directory
images = [f for f in os.listdir() if f.endswith('.png')]

# Setup Jinja2 environment
env = jinja2.Environment(
    loader=jinja2.FileSystemLoader(searchpath="./templates"),
    autoescape=jinja2.select_autoescape(['html', 'xml'])
)

# Load base template
template = env.get_template("time_plots.html")

# Render the template with the list of images
html_output = template.render(images=images)

# Write the output to a file
with open('timeplots.html', 'w') as f:
    f.write(html_output)


# Get the annual_plot.html template
template = env.get_template('annual_plot.html')
 
# Create a list to hold links to the individual plot pages
plot_links = []

# Loop over all CSV files in the csv/ directory
for csv_file in glob.glob('csv/*.csv'):
  # Compute the plot_id, norm_score_col, and score_col
  base_name = os.path.basename(csv_file)
  score_col = base_name.replace('_time.csv', '')
  norm_score_col = 'norm_' + score_col
  plot_id = 'plot_' + score_col.replace(' ', '_')

  # Render the template with the CSV data
  html = template.render(plot_id=plot_id, csv_file=csv_file, norm_score_col=norm_score_col, score_col=score_col)

  # Write the rendered HTML to a file
  html_file = './' + score_col + '_annual.html'
  with open(html_file, 'w') as f:
    f.write(html)

  # Add a link to this plot page to the list of plot links
  plot_links.append((score_col, html_file))

# Get the pluriannual_plots.html template
template = env.get_template('pluriannual_plots.html')

# Render the template with the list of plot links
html = template.render(plot_links=plot_links)

# Write the rendered HTML to a file
with open('PluriAnnual_dynamic.html', 'w') as f:
  f.write(html)
  
