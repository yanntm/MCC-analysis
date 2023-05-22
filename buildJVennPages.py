import os
import json
import pandas as pd
from jinja2 import Environment, FileSystemLoader

JSON_DIR = './'

def load_tool_indexes():
    tool_index_dict = {}

    with open(os.path.join(JSON_DIR, 'tool_data.json')) as f:
        data = json.load(f)
        for tool_name, tool_data in data.items():
            tool_index_dict[tool_name] = [str(index) for index in tool_data['answers']]
    
    return tool_index_dict

def write_json_file(filename, data):
    with open(filename, 'w') as f:
        json.dump(data, f)

def create_sorted_tool_list(tool_index_dict):
    return sorted(tool_index_dict.keys(), key=lambda x: len(tool_index_dict[x]), reverse=True)

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

def generate_html(tool_index_dict, sorted_tools, filters, template):
    output = template.render(tool_index_dict=tool_index_dict, sorted_tools=sorted_tools, filters=filters)

    with open('venn_dynamic.html', 'w') as f:
        f.write(output)

def main():
    env = Environment(loader=FileSystemLoader("./templates"))
    template = env.get_template('jvenn.html')

    categories = ['state_space', 'global_properties', 'reachability', 'ctl', 'ltl', 'upper_bounds']

    for category in categories:
        os.chdir(category)

        tool_index_dict = load_tool_indexes()
        write_json_file('tool_index_dict.json', tool_index_dict)

        sorted_tools = create_sorted_tool_list(tool_index_dict)

        df_resolution = load_resolution_file()

        filter_columns = ['Examination','ModelType']  # Update this list with any additional filter columns
        filters = generate_filters(df_resolution, filter_columns)
        write_filter_files(filters)

        generate_html(tool_index_dict, sorted_tools, filters, template)

        os.chdir('..')

if __name__ == "__main__":
    main()
