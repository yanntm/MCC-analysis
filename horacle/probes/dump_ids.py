#!/usr/bin/env python3
"""Probe: dump raw <id> values of RC/RF properties for given model dirs."""
import os
import sys
import xml.etree.ElementTree as ET

INPUTS = os.path.expanduser("~/git/pnmcc-models-2025/website/INPUTS")
MODELS = sys.argv[1:] or ["Medical-PT-06", "DBSingleClientW-PT-d1m09"]

for model in MODELS:
    d = os.path.join(INPUTS, model)
    print(f"=== {model}  (dir exists: {os.path.isdir(d)}) ===")
    if not os.path.isdir(d):
        continue
    for exam in ("ReachabilityCardinality", "ReachabilityFireability"):
        p = os.path.join(d, exam + ".xml")
        if not os.path.exists(p):
            print(f"  [missing {exam}.xml]")
            continue
        root = ET.parse(p).getroot()
        ns = root.tag.split('}')[0].strip('{')
        ids = [e.text for e in root.findall(f"{{{ns}}}property/{{{ns}}}id")]
        print(f"  {exam}: {len(ids)} ids")
        for i in ids[:4]:
            print(f"     {i}")
