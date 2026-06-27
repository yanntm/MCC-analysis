#!/usr/bin/env python3
"""Reproduce the horacle `forms<YEAR>.csv` file (the output of isag.go) in Python.

For every per-model `<model>.tgz` archive under the given INPUTS folder, read
ReachabilityCardinality.xml and ReachabilityFireability.xml *directly from the
archive* and, for each property, emit one line:

    <model>-<Examination>-<NN> <AG|EF> <size>

- Reading from the .tgz (not decompressed dirs) keeps us immune to any local
  edits to the extracted folders, and matches the natural post-install layout.
- key: <model dir name>-<examination>-<NN>, built from position like isag.go
  (the XML <id> is ignored, so no embedded year leaks into the key).
- modality: top temporal operator under <formula>
    all-paths/globally  -> AG ;  exists-path/finally -> EF
- size: number of element nodes in the formula subtree (best-effort; not yet
  validated against hue's formula.Size; unused downstream).
"""
import argparse
import os
import sys
import tarfile
import xml.etree.ElementTree as ET

EXAMINATIONS = ["ReachabilityCardinality", "ReachabilityFireability"]


def local(tag):
    return tag.rsplit('}', 1)[-1]


def modality(formula_el):
    children = list(formula_el)
    if not children:
        return None
    top = local(children[0].tag)
    return {"all-paths": "AG", "exists-path": "EF"}.get(top)


def size(formula_el):
    return sum(1 for _ in formula_el.iter())


def process_xml(fileobj, model, exam, out, unknown):
    root = ET.parse(fileobj).getroot()
    ns = root.tag.split('}')[0].strip('{')
    q = lambda t: f"{{{ns}}}{t}"
    for k, prop in enumerate(root.findall(q("property"))):
        formula_el = prop.find(q("formula"))
        if formula_el is None:
            continue
        key = f"{model}-{exam}-{k:02d}"
        mod = modality(formula_el)
        if mod is None:
            unknown.append(key)
            mod = "??"
        out.append((key, mod, size(formula_el)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-inputs", required=True, help="folder of per-model <model>.tgz")
    ap.add_argument("-o", default="-", help="output file (default stdout)")
    args = ap.parse_args()

    rows, unknown, nmodels = [], [], 0
    for fn in sorted(os.listdir(args.inputs)):
        if not fn.endswith(".tgz"):
            continue
        model = fn[:-4]
        nmodels += 1
        with tarfile.open(os.path.join(args.inputs, fn)) as tar:
            for exam in EXAMINATIONS:
                member = f"{model}/{exam}.xml"
                try:
                    f = tar.extractfile(member)
                except KeyError:
                    f = None
                if f is not None:
                    process_xml(f, model, exam, rows, unknown)

    rows.sort(key=lambda r: r[0].encode())  # bytewise (C locale), like the go pipeline

    fh = sys.stdout if args.o == "-" else open(args.o, "w")
    for key, mod, sz in rows:
        fh.write(f"{key} {mod} {sz}\n")
    if fh is not sys.stdout:
        fh.close()

    sys.stderr.write(f"{nmodels} models, {len(rows)} properties, "
                     f"{len(unknown)} with unknown modality\n")
    if unknown:
        sys.stderr.write("  e.g. " + ", ".join(unknown[:5]) + "\n")


if __name__ == "__main__":
    main()
