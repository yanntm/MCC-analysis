#!/usr/bin/env python3
"""Probe: is the RC cross-contamination present in the source .tgz archives,
or only in the decompressed dirs? Reads RC.xml straight from each .tgz."""
import os
import tarfile
import xml.etree.ElementTree as ET

INPUTS = os.path.expanduser("~/git/pnmcc-models-2025/website/INPUTS")

for model in ("Medical-PT-06", "DBSingleClientW-PT-d1m09"):
    tgz = os.path.join(INPUTS, model + ".tgz")
    print(f"=== {model}.tgz (exists: {os.path.exists(tgz)}) ===")
    if not os.path.exists(tgz):
        continue
    with tarfile.open(tgz) as t:
        member = f"{model}/ReachabilityCardinality.xml"
        try:
            f = t.extractfile(member)
        except KeyError:
            print(f"  [no {member} in archive]")
            continue
        root = ET.parse(f).getroot()
        ns = root.tag.split('}')[0].strip('{')
        ids = [e.text for e in root.findall(f"{{{ns}}}property/{{{ns}}}id")]
        print(f"  {len(ids)} RC properties; first id: {ids[0] if ids else 'NONE'}")
