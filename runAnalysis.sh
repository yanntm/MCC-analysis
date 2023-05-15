#!/bin/bash

set -x

download_data() {
  local YEAR=$1
  echo "Downloading data for year ${YEAR}..."
  
  if [ ! -f "raw-result-analysis.csv.zip" ] ; then
    curl "https://mcc.lip6.fr/${YEAR}/archives/raw-result-analysis.csv.zip" -o "raw-result-analysis.csv.zip"
  fi

  if [ ! -f "raw-result-analysis.csv" ] ; then
    unzip "raw-result-analysis.csv.zip" 
    rm -rf __MACOSX
  fi
}

process_year() {
  local year="$1"
  echo "Crunching data for $year"
  download_data "$year"
  mkdir website
  cp -r ../../templates website/
  Rscript ../../analyzeAnswers.R $year
  
  rm website/*.log
  # Convert TIFF images to PNG format
  cd website
  for tiff_image in *.tiff; do
    png_image="${tiff_image%.*}.png"
    convert "$tiff_image" "$png_image"
    rm "$tiff_image"
  done
  cd ..
  
  python3 ../../buildPages.py 
  cd website
  python3 ../../../buildVennPages.py
  cd .. 
  mv *.html website/
  python3 ../../buildFinalPages.py 
}

mkdir -p website
cd website

for year in {2016..2023}; do
	mkdir $year
	cd $year
	cp -r ../../templates .
	cp ../../templates/styles.css .
  	process_year "$year"
  	mv answers.csv website/
  	rm -r templates/
  	rm *
  	mv website/* .
  	cd ..
done


# generate time plots
Rscript ../analyzeAnnual.R


# generate HTML gallery for them
cp -r ../templates/ .
cp ../templates/styles.css .
python3 ../buildTimePlotPages.py
rm -rf templates/

cd ..


generate_main_index() {
  echo "Generating main index.html..."
  cat > website/index.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Model Checking Contest Analysis</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <h1>Model Checking Contest Analysis</h1>
  <p>Select a year to view the analysis:</p>
  <ul>
EOL

  for year in {2016..2023}; do
    cat >> website/index.html << EOL
    <li><a href="${year}/index.html">MCC ${year} Analysis</a></li>
EOL
  done

  cat >> website/index.html << EOL
  <a href="timeplots.html">PluriAnnual Plots</a>
</body>
</html>
EOL
}



generate_main_index

echo "Finished processing all years."
