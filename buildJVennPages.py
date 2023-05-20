import os
import json
import pandas as pd
from jinja2 import Environment, FileSystemLoader

# Define path where JSON files are stored
json_dir = './json/'

# Create a dictionary to store tool names and their corresponding indexes
tool_index_dict = {}

# Loop through each JSON file in the directory
for file_name in os.listdir(json_dir):
    if file_name.endswith('.json'):
        tool_name = os.path.splitext(file_name)[0]  # Get the tool name (file name without extension)
        with open(os.path.join(json_dir, file_name)) as f:
            data = json.load(f)
            tool_index_dict[tool_name] = data['answers']  # Store the "answers" indices in the dictionary

# Sort the tool_index_dict by number of elements in each tool's set
tool_index_dict = dict(sorted(tool_index_dict.items(), key=lambda item: len(item[1]), reverse=True))

# Set up Jinja2 template environment
env = Environment(loader=FileSystemLoader("templates"))

# Load Jinja2 template
template = env.get_template('jvenn.html')

# Render template with the tool_index_dict
output = template.render(tool_index_dict=tool_index_dict)

# Write the output to a HTML file
with open('venn_dynamic.html', 'w') as f:
    f.write(output)
