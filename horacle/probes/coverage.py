#!/usr/bin/env python3
"""Probe: forms vs resolution coverage for a year. Distinguishes UNKNOWNs that
are whole models absent from resolution (a key-mismatch bug) from scattered
no-consensus queries (expected)."""
import argparse
import csv
from collections import defaultdict

ap = argparse.ArgumentParser()
ap.add_argument("-forms", required=True)
ap.add_argument("-resolution", required=True)
args = ap.parse_args()

forms = defaultdict(set)
with open(args.forms) as f:
    for line in f:
        model, exam, qid = line.split()[0].rsplit("-", 2)
        forms[(model, exam)].add(qid)

reso = defaultdict(set)
with open(args.resolution) as f:
    for row in csv.DictReader(f):
        model = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}"
        reso[(model, row["Examination"])].add(row["ID"])

only_forms = set(forms) - set(reso)
whole_missing_rows = sum(len(forms[k]) for k in only_forms)
partial = sum(len(forms[k] - reso.get(k, set())) for k in set(forms) & set(reso))

print(f"forms groups={len(forms)} resolution groups={len(reso)}")
print(f"groups in forms but NOT resolution : {len(only_forms)}  ({whole_missing_rows} rows)")
print(f"scattered no-consensus queries     : {partial} rows")
models = sorted({m for (m, e) in only_forms})
print(f"distinct models absent from resolution: {len(models)}")
for m in models[:20]:
    print(f"  {m}")
