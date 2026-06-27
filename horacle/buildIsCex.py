#!/usr/bin/env python3
"""Build iscex<year>.csv (INV/CEX classification) from a modality file
(forms<year>.csv) and the pipeline's per-formula Consensus verdict.

This replaces the Go `conv` tool + `iscex.sh` + the manual oracle: the verdict
comes from the analysis' own fine-grain `Consensus` column (reachability
resolution.csv), combined with the formula modality:

    AG & TRUE  -> INV     AG & FALSE -> CEX
    EF & TRUE  -> CEX     EF & FALSE -> INV
    (no consensus, or unknown modality) -> UNKNOWN

Output imitates horacle/conv/iscex2023.csv: "<key> <INV|CEX|UNKNOWN>", one line
per reachability query, bytewise (C-locale) sorted, same keys as the forms file.
"""
import argparse
import csv

TABLE = {("AG", "TRUE"): "INV", ("AG", "FALSE"): "CEX",
         ("EF", "TRUE"): "CEX", ("EF", "FALSE"): "INV"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-forms", required=True, help="forms<year>.csv (key modality size)")
    ap.add_argument("-resolution", required=True,
                    help="reachability resolution.csv (has a Consensus column)")
    ap.add_argument("-o", required=True, help="output iscex<year>.csv")
    args = ap.parse_args()

    consensus = {}
    with open(args.resolution) as f:
        for row in csv.DictReader(f):
            key = (f"{row['ModelFamily']}-{row['ModelType']}-{row['ModelInstance']}"
                   f"-{row['Examination']}-{row['ID']}")
            consensus[key] = row["Consensus"].strip().upper()

    rows = []
    with open(args.forms) as f:
        for line in f:
            key, mod = line.split()[0], line.split()[1]
            verdict = consensus.get(key)
            cat = "UNKNOWN" if verdict is None else TABLE.get((mod, verdict), "UNKNOWN")
            rows.append((key, cat))

    rows.sort(key=lambda r: r[0].encode())
    with open(args.o, "w") as f:
        for key, cat in rows:
            f.write(f"{key} {cat}\n")

    from collections import Counter
    c = Counter(cat for _, cat in rows)
    print(f"{len(rows)} rows -> {args.o}  INV={c['INV']} CEX={c['CEX']} UNKNOWN={c['UNKNOWN']}")


if __name__ == "__main__":
    main()
