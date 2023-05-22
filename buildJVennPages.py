import os
import json
import pandas as pd
from jinja2 import Environment, FileSystemLoader

JSON_DIR = './'

def write_json_file(filename, data):
    with open(filename, 'w') as f:
        json.dump(data, f)

def create_sorted_tool_list():
    with open('tool_index_dict.json') as f:
        tool_index_dict = json.load(f)
    
    tools = list(tool_index_dict.keys())
    tools.sort(key=lambda x: len(tool_index_dict[x]['answers']), reverse=True)
    return tools

def load_resolution_file():
    return pd.read_csv('resolution.csv')

def generate_filters(df, filter_columns):
    filters = {col: {} for col in filter_columns}

    for col in filter_columns:
        unique_values = df[col].unique().tolist()

        for value in unique_values:
            index_set = set(df[df[col] == value]['Index'].astype(str))
            filters[col][value] = sorted(list(index_set))  # Convert set to list
    
    return filters

def write_filter_files(filters):
    write_json_file('filters.json', filters)

def generate_html(sorted_tools, filters, template):
    output = template.render(sorted_tools=sorted_tools, filters=filters)

    with open('venn_dynamic.html', 'w') as f:
        f.write(output)

def main():
    env = Environment(loader=FileSystemLoader("./templates"))
    template = env.get_template('jvenn.html')

    categories = ['state_space', 'global_properties', 'reachability', 'ctl', 'ltl', 'upper_bounds']

    for category in categories:
        os.chdir(category)

        sorted_tools = create_sorted_tool_list()  

        df_resolution = load_resolution_file()

        filter_columns = ['Examination','ModelType']  # Update this list with any additional filter columns
        filters = generate_filters(df_resolution, filter_columns)
        write_filter_files(filters)

        generate_html(sorted_tools, filters, template)

        os.chdir('..')

if __name__ == "__main__":
    main()
