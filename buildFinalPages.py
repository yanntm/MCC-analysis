import os
from pathlib import Path
from jinja2 import Environment, FileSystemLoader
from natsort import natsorted
import shutil

# Configure Jinja2 environment
env = Environment(loader=FileSystemLoader("templates"))
# Define the categories and their corresponding files
categories = {
    "State_Space": "state_space",
    "Global_Properties": "global_properties",
    "Reachability": "reachability",
    "CTL": "ctl",
    "LTL": "ltl",
    "Upper_Bounds": "upper_bounds"
}

# Create the index.html file
index_template = env.get_template("index.html")
with open("website/index.html", "w") as index_file:
    index_file.write(index_template.render(categories=categories))

# Create a page for each category
category_template = env.get_template("category.html")
for category_name, category_file in categories.items():
    table_html = Path(f"website/{category_file}.html").read_text()
    
    with open(f"website/{category_file}_final.html", "w") as category_file:
        category_file.write(category_template.render(
            category_name=category_name.replace("_", " "),
            table_html=table_html,
            category_file=categories[category_name]
        ))

shutil.copy("templates/styles.css", "website/styles.css")