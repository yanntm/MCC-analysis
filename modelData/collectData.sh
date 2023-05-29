#!/bin/bash

# Create CSV file with headers
echo "Model,Places,Transitions,Arcs" > ModelDescriptions.csv

# Iterate over all tgz files in the current directory
for file in *.tgz
do
    # Extract the file
    tar -xvzf "$file"
    # Get the directory name
    directory=$(basename "$file" .tgz)

    # Extract model name from directory
    model=$directory

    # Parse the XML file and count elements
    places=$(xmlstarlet sel -t -v 'count(_:pnml/_:net/_:page/_:place)' "$directory/model.pnml")
    transitions=$(xmlstarlet sel -t -v 'count(_:pnml/_:net/_:page/_:transition)' "$directory/model.pnml")
    arcs=$(xmlstarlet sel -t -v 'count(_:pnml/_:net/_:page/_:arc)' "$directory/model.pnml")

    # Write data to CSV
    echo "$model,$places,$transitions,$arcs" >> ModelDescriptions.csv

    # Remove the directory
    rm -rf "$directory"
done
