#!/usr/bin/env python3
"""Build the local campaign pages from a config of result sets.

    build.py config.json            # only the pages whose logs have moved
    build.py config.json --force    # every page, whatever the timestamps

A page is rebuilt when it is older than a log of its examination or than this
generator, so adding logs to one examination costs that examination alone.
**This assumes logs are only ever added.** A log that is deleted or replaced
in place leaves the others untouched, so nothing looks stale and the page
keeps its stale numbers: after removing logs, rebuild with --force (or empty
the output directory, which is the clean build).

The config names the result sets and where they come from, the oracle
directory of pnmcc-models-2026 (the consensus, the formula names, the backing
tools), the contest raw results file (per tool verdicts), and the output
directory:

    {"oracle": "/data/ythierry/MCC26deploy/MCC-drivers/oracle",
     "raw": "website/2026/raw-result-analysis.csv",
     "out": "/data/ythierry/MCC26logs/web/campaign",
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
import totals

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
        print(f"{rs.name}: {len(rs.runs)} runs, {len(rs.verdicts)} verdicts, {len(rs.totals)} total runs, examinations {rs.examinations()}", file=sys.stderr)
        sets.append(rs)
    return sets


def code_stamp():
    """When this generator last changed: a page older than that is stale."""
    here = os.path.dirname(os.path.abspath(__file__))
    newest = 0.0
    for root in (here, os.path.join(here, "templates"), os.path.join(here, "static")):
        if not os.path.isdir(root):
            continue
        for name in os.listdir(root):
            path = os.path.join(root, name)
            if os.path.isfile(path):
                newest = max(newest, os.path.getmtime(path))
    return newest


def input_stamp(sets, exam, floor):
    """When the logs behind one examination last changed, `floor` included."""
    newest = floor
    for rs in sets:
        for (_, e), r in rs.runs.items():
            if e == exam and r.get("log"):
                try:
                    newest = max(newest, os.path.getmtime(r["log"]))
                except OSError:
                    pass
        for (_, e), r in rs.totals.items():
            if e == exam and r.get("log"):
                try:
                    newest = max(newest, os.path.getmtime(r["log"]))
                except OSError:
                    pass
    return newest


def cached_summary(out, page, stamp, force):
    """The summary of a page that needs no rebuild, or None to rebuild it.

    A page is up to date when it and its summary are younger than every log
    behind it and than this generator: adding logs to one examination then
    costs that examination only, not the whole site. `--force` ignores all of
    it, and removing the output directory is the clean build.
    """
    if force:
        return None
    html = os.path.join(out, page)
    side = os.path.join(out, page + ".summary.json")
    if not (os.path.exists(html) and os.path.exists(side)):
        return None
    if os.path.getmtime(html) <= stamp or os.path.getmtime(side) <= stamp:
        return None
    with open(side) as f:
        return json.load(f)


def save_summary(out, page, summary):
    with open(os.path.join(out, page + ".summary.json"), "w") as f:
        json.dump(summary, f)


def main():
    args = [a for a in sys.argv[1:] if a != "--force"]
    force = "--force" in sys.argv[1:]
    if len(args) != 1:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    with open(args[0]) as f:
        config = json.load(f)
    out = config["out"]
    os.makedirs(out, exist_ok=True)
    oracle = resultsets.load_oracle(config["oracle"])
    print(f"oracle: {len(oracle.names)} (instance, examination) pairs, {len(oracle.values)} values", file=sys.stderr)
    if config.get("raw") and not any(oracle.backing.values()):
        resultsets.backing_from_raw(oracle, config["raw"])
        print("oracle files name no tools: backing read from the raw results", file=sys.stderr)
    sets = load_sets(config, oracle)
    # the total examinations have their own pages below; a run of one is not a crossref row
    exams = sorted({e for rs in sets for e in rs.examinations()} - set(totals.EXAMS))
    env = Environment(loader=FileSystemLoader(os.path.join(HERE, "templates")), autoescape=False)
    with open(os.path.join(HERE, "static", "app.js")) as f:
        app_js = f.read()
    with open(os.path.join(HERE, "static", "total.js")) as f:
        total_js = f.read()
    with open(os.path.join(HERE, "static", "campaign.css")) as f:
        css = f.read()
    stamp = time.strftime("%Y-%m-%d %H:%M")
    total_exams = [e for e in totals.EXAMS if any(x == e for rs in sets for (_, x) in rs.totals)]
    all_exams = exams + total_exams
    pages = []
    floor = code_stamp()
    for exam in exams:
        page = f"{exam}.html"
        keep = cached_summary(out, page, input_stamp(sets, exam, floor), force)
        if keep is not None:
            pages.append({"exam": exam, "page": page, "summary": keep})
            print(f"{page}: up to date", file=sys.stderr)
            continue
        data = crossref.crossref(sets, exam, oracle)
        html = env.get_template("exam.html").render(exam=exam, data=json.dumps(data), css=css, app_js=app_js, stamp=stamp, exams=all_exams)
        with open(os.path.join(out, page), "w") as f:
            f.write(html)
        pages.append({"exam": exam, "page": page, "summary": data["summary"]})
        save_summary(out, page, data["summary"])
        print(f"{page}: {len(data['instances'])} instances, {len(data['values'])} values, {os.path.getsize(os.path.join(out, page)) // 1024} kB", file=sys.stderr)
    for exam in total_exams:
        page = f"{exam}.html"
        keep = cached_summary(out, page, input_stamp(sets, exam, floor), force)
        if keep is not None:
            pages.append({"exam": exam, "page": page, "summary": keep, "total": True})
            print(f"{page}: up to date", file=sys.stderr)
            continue
        data = totals.page_data(sets, exam, oracle)
        html = env.get_template("total.html").render(exam=exam, data=json.dumps(data), css=css, app_js=total_js, stamp=stamp, exams=all_exams)
        with open(os.path.join(out, page), "w") as f:
            f.write(html)
        pages.append({"exam": exam, "page": page, "summary": data["summary"], "total": True})
        save_summary(out, page, data["summary"])
        print(f"{page}: {len(data['runs'])} instances, {os.path.getsize(os.path.join(out, page)) // 1024} kB", file=sys.stderr)
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
