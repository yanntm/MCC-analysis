from jinja2 import Environment, FileSystemLoader
import os
import re

def get_image_files():
    # Find all directories
    all_dirs = [d for d in os.listdir() if os.path.isdir(d)]
    
    # Find all directories that contain XXModelEase.png files
    year_dirs = [d for d in all_dirs if any(re.match(r'\w+ModelEase.png$', f) for f in os.listdir(d))]
    
    # Get the unique examinations from the filenames
    examinations = list(set(re.match(r'(\w+)ModelEase.png$', f).group(1) for d in year_dirs for f in os.listdir(d) if re.match(r'\w+ModelEase.png$', f)))
    
    # Organize the image files by year and examination
    image_files = {year: {examination: [f for f in os.listdir(year) if re.match(f'{examination}ModelEase.png$', f)] for examination in examinations} for year in sorted(year_dirs)}
    
    return image_files, sorted(year_dirs), sorted(examinations)

def create_html_page(image_files, years, examinations):
    # Set up Jinja2 template environment
    env = Environment(loader=FileSystemLoader("templates"))
    
    # Load the template
    template = env.get_template('ModelHardness.html')
    
    # Render the template
    html = template.render(image_files=image_files, years=years, examinations=examinations)
    
    # Write to file
    with open('hardness.html', 'w') as f:
        f.write(html)

image_files, years, examinations = get_image_files()
create_html_page(image_files, years, examinations)
