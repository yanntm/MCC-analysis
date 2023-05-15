import pandas as pd
import glob
import time

def custom_html_table(df):
    classes = []
    for col in df.columns:
        if col == df.columns[0]:
            classes.append("tool")
        elif col.endswith("error_total"):
            classes.append("total errors")
        elif col.endswith("_total"):
            classes.append("total")
        elif col.startswith("error"):
            classes.append("details errors")
        else:
            classes.append("details")

    table_html = '<table id="myTable" class="display dataTables_wrapper">'
    header = '<thead><tr>'
    for i, col in enumerate(df.columns):
        header += f'<th class="{classes[i]}">{col}</th>'
    header += '</tr></thead>'
    table_html += header

    table_html += df.to_html(header=False, index=False, classes="display", justify="left", escape=False, table_id=None)
    table_html = table_html.replace('<table border="1" class="dataframe display">', '')
    table_html = table_html.replace('</table>', '')
    table_html += '</table>'
    return table_html

def generate_html(df, output_filename):
    html_table = custom_html_table(df)

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <script src="https://code.jquery.com/jquery-3.6.4.min.js"></script>
      <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.13.4/css/jquery.dataTables.css">
      <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.13.4/js/jquery.dataTables.js"></script>
     </head>
    <body>
      <label><input type="checkbox" id="detailsToggle" checked> Show details</label>
      <label><input type="checkbox" id="errorsToggle"> Show errors</label>
      {html_table}
      <script>
        $(document).ready(function() {{
          let detailsVisible = true;
          let errorsVisible = false;
          let table = $('#myTable').DataTable({{
            "paging": false,
            "order": [[1, "desc"]]
          }});

          function updateVisibility() {{
            table.columns('.details:not(.errors)').visible(detailsVisible);
            table.columns('.details.errors').visible(detailsVisible && errorsVisible);
            table.columns('.total.errors').visible(errorsVisible);
          }}

          updateVisibility();

          $('#detailsToggle').on('change', function() {{
            detailsVisible = this.checked;
            updateVisibility();
          }});

          $('#errorsToggle').on('change', function() {{
            errorsVisible = this.checked;
            updateVisibility();
          }});
        }});
      </script>

    </body>
    </html>
    """

    with open(output_filename, 'w') as f:
        f.write(html)

# Find all CSV files in the current folder
csv_files = glob.glob('*.csv')

for csv_file in csv_files:
    if csv_file == 'raw-result-analysis.csv':
        continue  # Skip this file and move on to the next one

    start_time = time.time()  # Record the start time for processing the current file

    # Load the CSV file into a pandas dataframe
    df = pd.read_csv(csv_file)

    # Generate the HTML table for the current CSV file
    output_filename = csv_file.replace('.csv', '.html')
    generate_html(df, output_filename)

    elapsed_time = time.time() - start_time  # Calculate the elapsed time for processing the current file
    print(f"Processed {csv_file} in {elapsed_time:.2f} seconds.")  # Print the elapsed time for processing the current file

