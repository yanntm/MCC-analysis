import pandas as pd
import glob
import time


def generate_html(df, output_filename):
    html_table = df.to_html(index=False, classes='display', justify='left', table_id="myTable")

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <script src="https://code.jquery.com/jquery-3.6.4.min.js"></script>
      <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.13.4/css/jquery.dataTables.css">
      <script type="text/javascript" charset="utf8" src="https://cdn.datatables.net/1.13.4/js/jquery.dataTables.js"></script>
     </head>
    <body>
      {}
      <script>
        $(document).ready(function() {{
          $('#myTable').DataTable({{
            "paging": false,
            "order": [[1, "asc"]]
          }});
        }});
      </script>
    </body>
    </html>
    """.format(html_table)

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

    # Sort the dataframe by the first column (change as needed)
    df = df.sort_values(by=df.columns[0])

    # Generate the HTML table for the current CSV file
    output_filename = csv_file.replace('.csv', '.html')
    generate_html(df, output_filename)

    elapsed_time = time.time() - start_time  # Calculate the elapsed time for processing the current file
    print(f"Processed {csv_file} in {elapsed_time:.2f} seconds.")  # Print the elapsed time for processing the current file
