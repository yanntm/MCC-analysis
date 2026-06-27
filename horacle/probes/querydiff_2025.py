#!/usr/bin/env python3
"""Probe: confirm the forms/resolution row gap is queries dropped from
resolution (no consensus), not a structural mismatch."""
import csv
from collections import defaultdict

FORMS = "horacle/conv/forms2025.csv"
RESOLUTION = "website/2025/reachability/resolution.csv"

forms = defaultdict(set)
with open(FORMS) as f:
    for line in f:
        model, exam, qid = line.split()[0].rsplit("-", 2)
        forms[(model, exam)].add(qid)

reso = defaultdict(set)
with open(RESOLUTION) as f:
    for row in csv.DictReader(f):
        model = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}"
        reso[(model, row["Examination"])].add(row["ID"])

forms_sizes = defaultdict(int)
for k, q in forms.items():
    forms_sizes[len(q)] += 1
print("forms queries-per-group distribution:", dict(sorted(forms_sizes.items())))

deficit_groups = 0
deficit_rows = 0
examples = []
for k in forms:
    missing = forms[k] - reso.get(k, set())
    if missing:
        deficit_groups += 1
        deficit_rows += len(missing)
        if len(examples) < 8:
            examples.append((k, len(reso.get(k, set())), sorted(missing)))

print(f"groups where resolution has fewer queries than forms: {deficit_groups}")
print(f"total dropped queries (forms - resolution)          : {deficit_rows}")
print("examples (group, resolution_count, missing_ids):")
for k, n, miss in examples:
    print(f"  {k[0]} {k[1]}: reso={n}/16  missing={miss}")
