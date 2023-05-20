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
            # Convert the "answers" indices into strings
            tool_index_dict[tool_name] = [str(index) for index in data['answers']]

# Render the tool_index_dict into a JSON string
json_str = json.dumps(tool_index_dict)

# Write the JSON string to a file
with open('tool_index_dict.json', 'w') as f:
    f.write(json_str)
    
    
# Create a sorted list of tools by the number of elements in their set
sorted_tools = sorted(tool_index_dict.keys(), key=lambda x: len(tool_index_dict[x]), reverse=True)

# Read the resolution file into a pandas DataFrame
df_resolution = pd.read_csv('resolution.csv')

# Create a dictionary to store model types and their corresponding indexes
model_type_dict = {}

# Load the data from the CSV file
df = pd.read_csv('resolution.csv')

# Get the unique model types
unique_model_types = df['ModelType'].unique().tolist()

# Fill the model_type_dict
for model_type in unique_model_types:
    index_set = set(df[df['ModelType'] == model_type]['Index'].astype(str))
    model_type_dict[model_type] = index_set

# Write model type dictionaries to JSON files
for model_type, index_set in model_type_dict.items():
    with open(f'{model_type}.json', 'w') as f:
        json.dump(sorted(list(index_set)), f)  # convert set to list before dumping as JSON

# Set up Jinja2 template environment
env = Environment(loader=FileSystemLoader("templates"))

# Load Jinja2 template
template = env.get_template('jvenn.html')

# Render template with the tool_index_dict
output = template.render(tool_index_dict=tool_index_dict, sorted_tools=sorted_tools, model_types=unique_model_types)

# Write the output to a HTML file
with open('venn_dynamic.html', 'w') as f:
    f.write(output)
