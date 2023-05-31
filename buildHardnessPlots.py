import pandas as pd
import numpy as np
from jinja2 import Environment, FileSystemLoader

# Load original CSV file
df = pd.read_csv("ModelHardness.csv")

# Define ideal scores
ideal_scores = {'ctl': 32, 'global_properties': 5, 'ltl': 16, 'reachability': 32, 'state_space': 4, 'upper_bounds': 16}

# List all examination categories and years
categories = ['ctl', 'global_properties', 'ltl', 'reachability', 'state_space', 'upper_bounds']
years = list(range(2016, 2024))

# Create a new column 'ModelKey' as a concatenation of 'ModelFamily' and 'ModelType'
df['ModelKey'] = df['ModelFamily'] + "_" + df['ModelType']

# Initialize list to store data frames, one for each category
dfs = []
csv_files = []
# Initialize dictionary to store lowest scoring models of 2023
hardest_models_2023 = {}

# For each category, create a data frame with columns 'Year', 'ModelKey', 'Score', 'NormalizedScore'
for category in categories:
    # Initialize lists to store column data
    years_list = []
    model_keys_list = []
    scores_list = []
    normalized_scores_list = []
    
    # For each year, extract scores for this category
    for year in years:
        # Group by 'ModelKey' and calculate average score for this category in this year
        df_year = df.groupby('ModelKey')[f'{category}BVT{year}'].mean().reset_index()
        # Add this year to years_list
        years_list.extend([year]*len(df_year))
        # Add model keys to model_keys_list
        model_keys_list.extend(df_year['ModelKey'])
        # Add average scores to scores_list
        scores = df_year[f'{category}BVT{year}']
        scores_list.extend(scores)
        # Add normalized scores to normalized_scores_list
        normalized_scores_list.extend(scores / ideal_scores[category])
        # If year is 2023, update hardest_models_2023 dictionary
        if year == 2023:
            for key, score in df_year.values:
                if key not in hardest_models_2023 or score < hardest_models_2023[key]:
                    hardest_models_2023[key] = score
    
    # Create data frame for this category
    df_category = pd.DataFrame({
        'Year': years_list,
        'ModelKey': model_keys_list,
        'Score': scores_list,
        'NormalizedScore': normalized_scores_list
    })
    # Drop rows with missing score
    df_category = df_category.dropna(subset=['Score'])
    # Add data frame to list
    dfs.append(df_category)

    # Save the corresponding data frame to a CSV file and append the filename to csv_files
    filename = f"{category}.csv"
    df_category.to_csv(filename, index=False)
    csv_files.append(filename)

# Compute the ten "hardest" models (those with the lowest average score in 2023 over all categories)
ten_hardest_models = sorted(hardest_models_2023, key=hardest_models_2023.get)[:10]

# Set up Jinja2 template environment
env = Environment(loader=FileSystemLoader("templates"))

# Load the template
template = env.get_template('hardness_plot.html')

# Render the template
rendered_template = template.render(csv_files=csv_files, initial_model_keys=ten_hardest_models)

# Write the rendered template to a file
with open('hardness_plot_rendered.html', 'w') as f:
    f.write(rendered_template)
