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
  # Rscript ../../analyzeAnswers.R $year
  
  Rscript ../../buildRefinedResults.R
  HORACLE="../../horacle/conv/iscex$year.csv"
  if [ -f $HORACLE ] ; then
	  cp "../../horacle/conv/iscex$year.csv" ./iscex.csv
  fi
  cp ../../nupn/nupn.csv .
  Rscript ../../fuseFormulaType.R
  rm nupn.csv
  if [ -f "iscex.csv" ] ; then
  	rm iscex.csv
  fi
    
  python3 ../../buildJVennPages.py 
  
  for i in ctl/  global_properties/  ltl/  reachability/  state_space/  upper_bounds/ ; do 
  	cd $i;  
  	python3 ../../../buildHTMLFromCSV.py ; 
  	python3 ../../../csv_to_html.py resolution.csv ; 
  	cd .. ; 
  done
  python3 ../../buildFinalPages.py 
  
  Rscript ../../plotHardness.R
  
  rm raw-result-analysis.csv raw-result-analysis.csv.zip 
}

mkdir -p website
cd website

for ((year=2024; year > 2017; year--)); do 
	mkdir $year
	cd $year
	cp -r ../../templates .
	cp ../../templates/styles.css .
  	process_year "$year"
  	#mv answers.csv website/
  	rm -r templates/
  	# rm *
  	mv website/* .
  	cd ..
done


# generate time plots
mkdir -p csv
Rscript ../analyzeAnnual.R
# generate HTML gallery for them
cp -r ../templates/ .
cp ../templates/styles.css .
python3 ../buildTimePlotPages.py

# generate hardness plots page
python3 ../buildHardnessPage.py

# generate invcex
Rscript ../analyzeINVCEX.R
python3 ../buildInvCex.py

rm -rf templates/


# generate model size plots
mkdir models
cd models
cp ../../modelData/ModelDescriptions.csv .
Rscript ../../analyzeSizes.R
Rscript ../../analyzeHardness.R
cp -r ../../templates/ . ; python3 ../../buildModelPages.py
python3 ../../buildHardnessPlots.py
cp templates/styles.css .
rm -rf templates
cd ..

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

  for year in {2018..2024}; do
    cat >> website/index.html << EOL
    <li><a href="${year}/index.html">MCC ${year} Analysis</a></li>
EOL
  done

  cat >> website/index.html << EOL
  <a href="PluriAnnual_dynamic.html">Dynamic Pluriannual plots</a><br/>
  <a href="models/models.html">Analysis of the Models of MCC</a><br/>
  <a href="models/hardness_plot_rendered.html">Model Hardness: Dynamic Pluriannual plots</a><br/>
  <a href="hardness.html">Model Hardness: Static plots</a><br/>
  <a href="invcex/invcex.html">Analysis of Invariants vs Counter-examples (Formulas)</a><br/>
  <a href="invcex/toolinvcex.html">Analysis of Invariants vs Counter-examples (Tools)</a><br/>
  <a href="invcex/toolinvcexhard.html">Analysis of Invariants vs Counter-examples (Tools + Hard)</a><br/>
</body>
</html>
EOL
}



generate_main_index

echo "Finished processing all years."
