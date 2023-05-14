import os
import glob
import time
import re
from jinja2 import Environment, FileSystemLoader

import pandas as pd

# Define categories and examinations
categories = {
    "state_space": ["StateSpace"],
    "global_properties": ["Liveness", "QuasiLiveness", "StableMarking", "ReachabilityDeadlock", "OneSafe"],
    "reachability": ["ReachabilityCardinality", "ReachabilityFireability"],
    "ctl": ["CTLCardinality", "CTLFireability"],
    "ltl": ["LTLCardinality", "LTLFireability"],
    "upper_bounds": ["UpperBounds"]
}

# Set up Jinja2 template environment
env = Environment(loader=FileSystemLoader("templates"))

# Find all Venn diagram image files in the current folder
venn_files = glob.glob("*_venn.png")

print("VENN files:", venn_files)

# Group Venn diagram files by examination
examination_files = {}
for venn_file in venn_files:
    match = re.match(r"(\w+)_\d+_venn\.png", venn_file)
    if match:
        examination = match.group(1)
        if examination not in examination_files:
            examination_files[examination] = []
        examination_files[examination].append(venn_file)

print("VENN Examination files:", examination_files)


# Generate HTML pages for each category
for category, examinations in categories.items():
    venn_files_for_category = []
    for examination in examinations:
        if examination in examination_files:
            venn_files_for_examination = examination_files[examination]
            venn_files_for_category.extend((venn_file, examination) for venn_file in venn_files_for_examination)

    # Render the Venn diagrams page using the Jinja2 template
    template = env.get_template("venn.html")
    output_html = template.render(
        category_name=category,
        examinations=examinations,
        venn_files=venn_files_for_category
    )

    # Save the generated HTML to a file
    output_filename = f"{category}_venn.html"
    with open(output_filename, "w") as output_file:
        output_file.write(output_html)

    print(f"Generated {output_filename} for category {category}")
