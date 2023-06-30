from jinja2 import Environment, FileSystemLoader
import pandas as pd
import json

# Load the data
df = pd.read_csv("invcex/formulas.csv")

# Convert the data to a JSON-like format
data = []
for formula_type in df['FormulaType'].unique():
    df_subset = df[df['FormulaType'] == formula_type]
    data.append({
        'x': df_subset['Year'].tolist(),
        'y': df_subset['Proportion'].tolist(),
        'name': formula_type,
        'type': 'bar'
    })

# Configure Jinja2 environment
env = Environment(loader=FileSystemLoader('./templates'))

# Create the index.html file
index_template = env.get_template("invcex.html")
with open("invcex/invcex.html", "w") as index_file:
    index_file.write(index_template.render(data=json.dumps(data)))
