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


# Define categories and examinations
categories = {
    "state_space": ["StateSpace"],
    "global_properties": ["Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe"],
    "reachability": ["ReachabilityCardinality", "ReachabilityFireability"],
    "ctl": ["CTLCardinality", "CTLFireability"],
    "ltl": ["LTLCardinality", "LTLFireability"],
    "upper_bounds": ["UpperBounds"]
}

# Get the annual_plot.html template
template = env.get_template('annual_plot.html')

# Create a list to hold links to the individual plot pages
plot_links = []

# Loop over all categories
for category, examinations in categories.items():
    # List of CSV files for the category and its examinations
    csv_files = [f'csv/answer_{category}_time.csv']
    csv_files += [f'csv/answer_{examination}_time.csv' for examination in examinations]
    
    # Compute the plot_id
    plot_id = 'plot_' + category

    # Render the template with the CSV data
    html = template.render(plot_id=plot_id, csv_files=csv_files,min_year=2016,max_year=2025)

    # Write the rendered HTML to a file
    html_file = './' + category + '_annual.html'
    with open(html_file, 'w') as f:
        f.write(html)

    # Add a link to this plot page to the list of plot links
    plot_links.append((category, html_file))

# Get the pluriannual_plots.html template
template = env.get_template('pluriannual_plots.html')

# Render the template with the list of plot links
html = template.render(plot_links=plot_links)

# Write the rendered HTML to a file
with open('PluriAnnual_dynamic.html', 'w') as f:
  f.write(html)
  
