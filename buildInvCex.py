from jinja2 import Environment, FileSystemLoader
import pandas as pd
import json

# Configure Jinja2 environment
env = Environment(loader=FileSystemLoader('./templates'))

# Create the index.html file
index_template = env.get_template("invcex.html")
with open("invcex/invcex.html", "w") as index_file:
    index_file.write(index_template.render())


# Create the toolinvcex.html file
template = env.get_template("toolinvcex.html")
with open("invcex/toolinvcex.html", "w") as out_file:
    out_file.write(template.render())
    

# Create the toolinvcex.html file
template = env.get_template("toolinvcexhard.html")
with open("invcex/toolinvcexhard.html", "w") as out_file:
    out_file.write(template.render())
