import os
import jinja2

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
