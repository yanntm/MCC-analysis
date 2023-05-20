import os
import json
import pandas as pd
from jinja2 import Environment, FileSystemLoader

JSON_DIR = './json/'

def load_tool_indexes():
    tool_index_dict = {}

    for file_name in os.listdir(JSON_DIR):
        if file_name.endswith('.json'):
            tool_name = os.path.splitext(file_name)[0]
            with open(os.path.join(JSON_DIR, file_name)) as f:
                data = json.load(f)
                tool_index_dict[tool_name] = [str(index) for index in data['answers']]
    
    return tool_index_dict

def write_json_file(filename, data):
    with open(filename, 'w') as f:
        json.dump(data, f)

def create_sorted_tool_list(tool_index_dict):
    return sorted(tool_index_dict.keys(), key=lambda x: len(tool_index_dict[x]), reverse=True)

def load_resolution_file():
    return pd.read_csv('resolution.csv')

def generate_filters(df, column_name):
    unique_values = df[column_name].unique().tolist()
    filter_dict = {}

    for value in unique_values:
        index_set = set(df[df[column_name] == value]['Index'].astype(str))
        filter_dict[value] = index_set

    return filter_dict, unique_values

def write_filter_files(filter_dict):
    for value, index_set in filter_dict.items():
        write_json_file(f'{value}.json', sorted(list(index_set)))

def generate_html(tool_index_dict, sorted_tools, unique_values):
    env = Environment(loader=FileSystemLoader("templates"))
    template = env.get_template('jvenn.html')
    output = template.render(tool_index_dict=tool_index_dict, sorted_tools=sorted_tools, model_types=unique_values)

    with open('venn_dynamic.html', 'w') as f:
        f.write(output)

def main():
    tool_index_dict = load_tool_indexes()
    write_json_file('tool_index_dict.json', tool_index_dict)

    sorted_tools = create_sorted_tool_list(tool_index_dict)

    df_resolution = load_resolution_file()

    model_type_dict, unique_model_types = generate_filters(df_resolution, 'ModelType')
    write_filter_files(model_type_dict)

    generate_html(tool_index_dict, sorted_tools, unique_model_types)

if __name__ == "__main__":
    main()
