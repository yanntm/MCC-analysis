#!/bin/bash

set -x

download_data() {
    local YEAR=$1

    # Attempt to download the .zip file if it doesn't exist
    if [ ! -f "raw-result-analysis.csv.zip" ]; then
        curl -s "https://mcc.lip6.fr/${YEAR}/archives/raw-result-analysis.csv.zip" -o "raw-result-analysis.csv.zip"
    fi

    # Check if the .zip file is too small (≤ 10KB), indicating it’s invalid
    if [ $(stat -c%s "raw-result-analysis.csv.zip" 2>/dev/null || echo 0) -le 10000 ]; then
        # Remove the .zip file to ensure we start fresh
        rm -f "raw-result-analysis.csv.zip"
        # Download and process the .tar.gz file
        curl -s "https://mcc.lip6.fr/${YEAR}/archives/raw-result-analysis.csv.tar.gz" -o "raw-result-analysis.csv.tar.gz"
        tar -xzf "raw-result-analysis.csv.tar.gz"
        # Create a new .zip file from the extracted CSV
        zip "raw-result-analysis.csv.zip" "raw-result-analysis.csv"
        # Clean up the .tar.gz file
        rm -f "raw-result-analysis.csv.tar.gz"
    fi

    # Unzip the .zip file (should now be valid)
    unzip -o "raw-result-analysis.csv.zip"
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
  
  rm -f raw-result-analysis.csv raw-result-analysis.csv.zip raw-result-analysis.csv.tar.gz 
}

mkdir -p website
cd website

for ((year=2025; year > 2017; year--)); do 
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

  for year in {2018..2025}; do
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
