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
  Rscript ../../analyzeAnswers.R 
  
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
  mv *.html website/
  python3 ../../buildFinalPages.py 
}

mkdir -p website
cd website

for year in {2017..2023}; do
	mkdir $year
	cd $year
	cp -r ../../templates .
  	process_year "$year"
  	cd ..
done

cd ..

echo "Finished processing all years."
