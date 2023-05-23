import csv
import sys
import os

def csv_to_html(csv_file):
    # Create the HTML file path
    html_file = os.path.splitext(csv_file)[0] + '.html'

    # Open the CSV file
    with open(csv_file, 'r') as csvfile:
        reader = csv.reader(csvfile)
        rows = list(reader)

    # Create the HTML table
    html_table = '<table>\n'

    # Generate the table header
    html_table += '  <tr>\n'
    for cell in rows[0]:
        html_table += f'    <th>{cell}</th>\n'
    html_table += '  </tr>\n'

    # Generate the table rows
    for row in rows[1:]:
        html_table += '  <tr>\n'
        for cell in row:
            html_table += f'    <td>{cell}</td>\n'
        html_table += '  </tr>\n'

    html_table += '</table>'

    # Write the HTML table to the file
    with open(html_file, 'w') as htmlfile:
        htmlfile.write(html_table)

    print(f"HTML table generated: {html_file}")

# Check if CSV files are provided as arguments
if len(sys.argv) < 2:
    print("Please provide the CSV file(s) as arguments.")
    sys.exit(1)

# Process each CSV file
for csv_file in sys.argv[1:]:
    # Check if the CSV file exists
    if not os.path.isfile(csv_file):
        print(f"CSV file not found: {csv_file}")
        continue

    # Convert the CSV file to HTML
    csv_to_html(csv_file)
