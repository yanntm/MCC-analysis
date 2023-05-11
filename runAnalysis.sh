#!/bin/bash

# Create the "website" folder 
mkdir -p website

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
rm website/*.log

# Run the Python script
python3 buildPages.py
mv *.html website/

python3 buildFinalPages.py


# Remove the downloaded zip file and raw-result-analysis.csv
#rm raw-result-analysis.csv.zip
#rm raw-result-analysis.csv

