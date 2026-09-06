#!/usr/bin/env python3
"""Build the local campaign pages from a config of result sets.

    build.py config.json

The config names the result sets and where they come from, the oracle
directory of pnmcc-models-2026 (the consensus, the formula names, the backing
tools), the contest raw results file (per tool verdicts), and the output
directory:

    {"oracle": "/data/ythierry/MCC26run/oracle-2026/oracle",
     "raw": "website/2026/raw-result-analysis.csv",
     "out": "/data/ythierry/MCC26run/pages",
     "sets": [
        {"name": "petrispot 2026-09-06", "logs": ["/data/ythierry/MCC26run/2026-09-06/RD", "..."], "extractors": "itstools"},
        {"name": "ITS-Tools 2026", "contest": "ITS-Tools"},
        {"name": "Tapaal 2026", "contest": "Tapaal"}]}

One page per examination any set covers, plus an index. The pages are static
HTML with the data embedded as JSON; tables and plots are built in the
browser (DataTables, Plotly from their CDNs). Log files are linked as
`logs/<absolute path>`, which `serve.py` answers from the local disk; the
log directories it may read are written to `roots.json` next to the pages.
"""

import json
import os
import shutil
import sys
import time

from jinja2 import Environment, FileSystemLoader

import crossref
import resultsets

HERE = os.path.dirname(os.path.abspath(__file__))


def load_sets(config, oracle):
    sets = []
    for s in config["sets"]:
        if "logs" in s:
            extractors = []
            if s.get("extractors") == "itstools":
                import itstools
                extractors = itstools.EXTRACTORS
            rs = resultsets.load_logs(s["name"], s["logs"], extractors)
        elif "contest" in s:
            rs = resultsets.load_contest(s["name"], config["raw"], s["contest"], oracle)
        else:
            raise ValueError(f"set {s.get('name')} has neither logs nor contest")
        print(f"{rs.name}: {len(rs.runs)} runs, {len(rs.verdicts)} verdicts, examinations {rs.examinations()}", file=sys.stderr)
        sets.append(rs)
    return sets


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        config = json.load(f)
    out = config["out"]
    os.makedirs(out, exist_ok=True)
    oracle = resultsets.load_oracle(config["oracle"])
    print(f"oracle: {len(oracle.names)} (instance, examination) pairs, {len(oracle.values)} values", file=sys.stderr)
    if config.get("raw") and not any(oracle.backing.values()):
        resultsets.backing_from_raw(oracle, config["raw"])
        print("oracle files name no tools: backing read from the raw results", file=sys.stderr)
    sets = load_sets(config, oracle)
    exams = sorted({e for rs in sets for e in rs.examinations()})
    env = Environment(loader=FileSystemLoader(os.path.join(HERE, "templates")), autoescape=False)
    with open(os.path.join(HERE, "static", "app.js")) as f:
        app_js = f.read()
    with open(os.path.join(HERE, "static", "campaign.css")) as f:
        css = f.read()
    stamp = time.strftime("%Y-%m-%d %H:%M")
    pages = []
    for exam in exams:
        data = crossref.crossref(sets, exam, oracle)
        page = f"{exam}.html"
        html = env.get_template("exam.html").render(exam=exam, data=json.dumps(data), css=css, app_js=app_js, stamp=stamp, pages=[f"{e}.html" for e in exams], exams=exams)
        with open(os.path.join(out, page), "w") as f:
            f.write(html)
        pages.append({"exam": exam, "page": page, "summary": data["summary"]})
        print(f"{page}: {len(data['instances'])} instances, {len(data['values'])} values, {os.path.getsize(os.path.join(out, page)) // 1024} kB", file=sys.stderr)
    html = env.get_template("index.html").render(pages=pages, sets=[{"name": rs.name, "source": json.dumps(rs.source)} for rs in sets], css=css, stamp=stamp)
    with open(os.path.join(out, "index.html"), "w") as f:
        f.write(html)
    # the directories serve.py may read logs from
    roots = sorted({d for rs in sets for d in rs.source.get("logs", [])})
    with open(os.path.join(out, "roots.json"), "w") as f:
        json.dump(roots, f, indent=1)
    print(f"{os.path.join(out, 'index.html')}", file=sys.stderr)


if __name__ == "__main__":
    main()
