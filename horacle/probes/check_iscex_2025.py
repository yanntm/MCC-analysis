#!/usr/bin/env python3
"""Probe: join forms2025 modality with the pipeline's Consensus verdict and
classify INV/CEX, to validate the full chain on real 2025 data.

modality x Consensus truth table:
    AG & TRUE  -> INV     AG & FALSE -> CEX
    EF & TRUE  -> CEX     EF & FALSE -> INV
"""
import csv
import re
import sys

FORMS = "horacle/conv/forms2025.csv"
RESOLUTION = "website/2025/reachability/resolution.csv"

YEAR = re.compile(r"-(?:19|20)\d\d-(\d\d)$")


def strip_year(key):
    """ARMCacheCoherence-...-ReachabilityCardinality-2025-00 -> ...-00"""
    return YEAR.sub(r"-\1", key)


TABLE = {("AG", "TRUE"): "INV", ("AG", "FALSE"): "CEX",
         ("EF", "TRUE"): "CEX", ("EF", "FALSE"): "INV"}


def main():
    modality = {}
    with open(FORMS) as f:
        for line in f:
            pid, mod, _size = line.split()
            modality[strip_year(pid)] = mod

    counts = {"INV": 0, "CEX": 0, "UNKNOWN": 0}
    matched = unmatched = 0
    with open(RESOLUTION) as f:
        for row in csv.DictReader(f):
            key = f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}-{row['Examination']}-{row['ID']}"
            mod = modality.get(key)
            if mod is None:
                unmatched += 1
                continue
            matched += 1
            verdict = row["Consensus"].strip().upper()
            counts[TABLE.get((mod, verdict), "UNKNOWN")] += 1

    print(f"forms modality keys : {len(modality)}")
    print(f"resolution matched  : {matched}")
    print(f"resolution unmatched: {unmatched}")
    print(f"INV={counts['INV']}  CEX={counts['CEX']}  UNKNOWN={counts['UNKNOWN']}")


if __name__ == "__main__":
    main()
