#!/bin/bash

# Download and unzip the results file
if [ ! -f raw-result-analysis.csv.zip ] ; then
	curl -O https://mcc.lip6.fr/2023/archives/raw-result-analysis.csv.zip
fi

if [ ! -f raw-result-analysis.csv ] ; then
	unzip raw-result-analysis.csv.zip
	rm -rf __MACOSX
fi

# Run the R script
Rscript analyzeAnswers.R

# Run the Python script
python3 buildPages.py

# Create an index.html file
cat <<EOT > index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Analysis Results</title>
</head>
<body>
    <h1>Analysis Results</h1>
    <ul>
        <li><a href="images.html">Plots</a></li>
EOT


# Convert TIFF images to PNG format
for tiff_image in *.tiff; do
    png_image="${tiff_image%.*}.png"
    convert "$tiff_image" "$png_image"
    rm "$tiff_image"
done



# Add links to generated HTML pages
for html_file in $(ls *.html | grep -v -E '^(index|images).html$'); do
    echo "        <li><a href=\"$html_file\">$(basename "$html_file" .html)</a></li>" >> index.html
done

cat <<EOT >> index.html
    </ul>
</body>
</html>
EOT

# Create an images.html file to show the PNG images
cat <<EOT > images.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Plots</title>
</head>
<body>
    <h1>Plots</h1>
EOT

# Add img tags for each generated PNG image
for image_file in $(ls *.png | sort -V); do
    echo "    <img src=\"$image_file\" alt=\"$(basename "$image_file" .png)\">" >> images.html
done

cat <<EOT >> images.html
</body>
</html>
EOT

# Create the "website" folder and move the required files
mkdir -p website
mv *.html website/
mv *.png website/
mv *.csv website/

# Remove the downloaded zip file and raw-result-analysis.csv
#rm raw-result-analysis.csv.zip
#rm raw-result-analysis.csv

