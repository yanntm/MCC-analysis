#!/usr/bin/env python3
"""Probe: why does forms2025 have more rows than the reachability resolution?
Compare the (model, examination) coverage of each side."""
import csv
from collections import defaultdict

FORMS = "horacle/conv/forms2025.csv"
RESOLUTION = "website/2025/reachability/resolution.csv"

forms = defaultdict(int)        # (model, exam) -> nb queries
with open(FORMS) as f:
    for line in f:
        key = line.split()[0]
        model, exam, _id = key.rsplit("-", 2)
        forms[(model, exam)] += 1

reso = defaultdict(int)
with open(RESOLUTION) as f:
    for row in csv.DictReader(f):
        model = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}"
        reso[(model, row["Examination"])] += 1

forms_keys, reso_keys = set(forms), set(reso)
only_forms = forms_keys - reso_keys
only_reso = reso_keys - forms_keys

print(f"forms (model,exam) groups      : {len(forms_keys)}  rows={sum(forms.values())}")
print(f"resolution (model,exam) groups : {len(reso_keys)}  rows={sum(reso.values())}")
print(f"in forms but NOT resolution    : {len(only_forms)} groups, "
      f"{sum(forms[k] for k in only_forms)} rows")
print(f"in resolution but NOT forms    : {len(only_reso)} groups")

# Distinct models (ignoring exam) present only in forms
models_only_forms = {m for (m, e) in only_forms} - {m for (m, e) in reso_keys}
print(f"\nmodels entirely absent from resolution: {len(models_only_forms)}")
for m in sorted(models_only_forms)[:40]:
    print(f"  {m}")
