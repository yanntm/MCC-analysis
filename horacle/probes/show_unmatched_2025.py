#!/usr/bin/env python3
"""Probe: list the resolution.csv reachability rows that have no modality in
forms2025, and any duplicate forms keys after year-stripping."""
import csv
import re
from collections import Counter

FORMS = "horacle/conv/forms2025.csv"
RESOLUTION = "website/2025/reachability/resolution.csv"
YEAR = re.compile(r"-(?:19|20)\d\d-(\d\d)$")


def strip_year(key):
    return YEAR.sub(r"-\1", key)


modality = {}
dup = Counter()
with open(FORMS) as f:
    for line in f:
        pid, mod, _ = line.split()
        k = strip_year(pid)
        dup[k] += 1
        modality[k] = mod

print("=== duplicate forms keys (after year strip) ===")
for k, n in dup.items():
    if n > 1:
        print(f"  {k} x{n}")

print("=== unmatched resolution rows (no modality) ===")
models = Counter()
with open(RESOLUTION) as f:
    for row in csv.DictReader(f):
        key = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}-{row['Examination']}-{row['ID']}"
        if key not in modality:
            models[f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}"] += 1
for m, n in models.most_common():
    print(f"  {m}: {n} rows")
