# How to generate oracle files and other infos

## How to generate file reachXXX

* uncompress the GlobalSummary csv file from the MCC website

* use Excel to keep only the results for RC and RF, for only one tool. Remove
  unimportant columns

* Look for lines with only `? 0` at end of line; these are models with no
  results at all. Change them to `???????????????? 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  0`

* Change `\?` into `?` and then `\?(\d)` into `? $1`, for unknown verdicts at
  the end of a line.

* use `export LC_COLLATE="C"` and then `sort -o` the reach file to have a sorted
  result with uppercase letters always before lower case.

* __Remark:__ there are formulas for model DotAndBoxes in 2020 but no summary
  results.

## Files format

All data files are space separated values. We use both csv and txt for the file
extensions.

File `reachXXXX.txt` are csv with 18 values: `complete instance name`
(Model-type-instance, where type is either PT or COL) ; `expected verdicts`
(with `?` for unknown values) ; and a `difficulty level`, meaning the sum of the
confidence values of all tools that have answered the query (so one for each of
the 16 instances).

The difficulty level gives an indication on the difficulty of the query (the
less the highest).

We build the oracle file, `oracle_reachXXXX.txt`, from the `reachXXXX.txt` file
using the conv tool. The file has one line by query with its verdict and
difficulty level. The file is stored together in directory `horacle/htest`
because it is needed to build the htest tool.

The `formXXXX.csv` file has 3 columns: `complete query name`, concatenation of
the instance name and the query identifier (between 00 and 15) ; its top=level
`modality`, either AG or EF; and its `size`, in number of operators and atomic
propositions. It is generated from the `models+formulas` archive found in the
MCC website (after decompression), using the forms tool.

File `iscexXXX.csv` lists for every query if it is an invariant (INV) ; a
formula that can be decided by a counter-example (CEX) ; or if it is undecided
(UNKNOWN). The last case stem from verdicts that have no consensus.
