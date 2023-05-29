import os
import jinja2
import pandas as pd

# Find all png files in current directory
png_files = [f for f in os.listdir() if f.endswith('.png')]

# Function to define custom sort order
def sort_func(filename):
    if "Places" in filename:
        return 1
    elif "Transitions" in filename:
        return 2
    elif "Arcs" in filename:
        return 3
    elif "box_plot" in filename:
        return 4
    else:
        return 5

# Create a dictionary mapping category to png files
image_dict = {
    'All': sorted([f for f in png_files if 'All' in f], key=sort_func),
    'COL': sorted([f for f in png_files if 'COL' in f], key=sort_func),
    'PT': sorted([f for f in png_files if 'PT' in f], key=sort_func)
}

# Load Jinja2 environment
env = jinja2.Environment(loader=jinja2.FileSystemLoader('./templates/'))
template = env.get_template('models.html')

# Load the data
df = pd.read_csv('ModelDescriptions.csv')

# Split Model column into ModelFamily, ModelType, ModelInstance
df[['ModelFamily', 'ModelType', 'ModelInstance']] = df['Model'].str.split('-', expand=True)

# Calculate the metrics
total_model_instances = df['Model'].nunique()
total_model_families = df['ModelFamily'].nunique()
total_COL_model_families = df[df['ModelType'] == 'COL']['ModelFamily'].nunique()
total_PT_model_instances = df[df['ModelType'] == 'PT']['Model'].nunique()
total_COL_model_instances = df[df['ModelType'] == 'COL']['Model'].nunique()

# Prepare the variables for the template
template_variables = {
    "image_files": image_dict,
    "total_model_instances": total_model_instances,
    "total_model_families": total_model_families,
    "total_COL_model_families": total_COL_model_families,
    "total_PT_model_instances": total_PT_model_instances,
    "total_COL_model_instances": total_COL_model_instances
}

# Render the template and write it to models.html
with open("models.html", "w") as f:
    f.write(template.render(template_variables, image_files=image_dict))

# Reorder and drop redundant 'Model' column
df = df[['ModelFamily', 'ModelType', 'ModelInstance', 'Places', 'Transitions', 'Arcs']]

# Generate table HTML
table_html = df.to_html(index=False, classes="display", justify="left", escape=False, table_id="myTable")

# Generate the final HTML including DataTable initialization
html = f"""
<!DOCTYPE html>
<html>
<head>
  <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.11.3/css/jquery.dataTables.min.css">
  <script type="text/javascript" charset="utf8" src="https://code.jquery.com/jquery-3.6.4.min.js"></script>
  <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.11.3/js/jquery.dataTables.min.js"></script>
</head>
<body>
  Currently showing: 
  <select id="modelTypeSelect">
    <option value="">All</option>
    <option value="COL">COL</option>
    <option value="PT">PT</option>
  </select> models
  <br/>
  {table_html}
  <script>
    $(document).ready(function() {{
      var table = $('#myTable').DataTable({{
        "pageLength": 25,
        "caseInsensitive": false
      }});

      $('#modelTypeSelect').on('change', function() {{
        table
          .column(1) // modelType is the second column (0-indexed)
          .search(this.value)
          .draw();
      }});
    }});
  </script>
</body>
</html>"""

# Write to file
with open('ModelDescriptions.html', 'w') as f:
    f.write(html)
    

    