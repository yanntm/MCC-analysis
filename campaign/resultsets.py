"""Result sets: the verdicts of one tool configuration on the MCC benchmark.

A result set is what one tool, in one version and with one set of flags,
answered on every (model instance, examination, formula) it was run on, with
the wall time per run and, when the set comes from logs, the log file itself.
Two loaders build the same object:

* `load_logs(name, dirs)` reads harness logs of `run_test.pl` (MCC-drivers):
  the `Control values :` block names the formulas in order, the FORMULA and
  STATE_SPACE lines are the answers, the teamcity `all` marker the duration.
  Tool agnostic; a caller may pass `extractors` (see itstools.py) to pull
  tool specific counters into `extra`.
* `load_contest(name, raw_csv, tool)` reads one tool out of the contest's
  `raw-result-analysis.csv` (positional tokens per formula, time, status).

`load_consensus(raw_csv)` is the field's estimated result, with the tools
backing each value, the reference the "missed / bonus / wrong" vocabulary is
defined against.
"""

import collections
import csv
import os
import re

RE_INDEX = re.compile(r"-(\d\d)$")
RE_SYSCALL = re.compile(r"^syscalling : (.*)$")
RE_VERDICT = re.compile(r"^(?:FORMULA|STATE_SPACE)\s+(\S+)\s+(\S+)")
RE_TC_ALL = re.compile(r"##teamcity\[testFinished name='all'.*?duration='(\d+)'")
RE_TIMEOUT = re.compile(r"^Timeout set at :(\d+) seconds")
RE_TITLE = re.compile(r"^Running test : (\S+)")

NO_ANSWER = {"DNC", "DNF", "CC", "?", ""}
VIRTUAL = {"BVT-2026", "BVT-2025", "BVT-2024"}

# the first pattern found names the failure of a run that produced nothing
FAILURES = [
    ("no_input", "Cannot open file"),
    ("overlarge_marking", "OverlargeMarkingException"),
    ("eclipse_fatal", "An error has occurred. See the log file"),
    ("out_of_memory", "OutOfMemoryError"),
    ("its_abort", "terminate called"),
]


def normalize(v):
    """One spelling per verdict: TRUE, FALSE, an integer, +inf."""
    v = v.strip()
    if v == "T":
        return "TRUE"
    if v == "F":
        return "FALSE"
    v = re.sub(r"(\d)\.0000E\+0005", r"\g<1>00000", v)
    if v.endswith("inf"):
        return "+inf"
    return v


# examinations whose verdicts are numbers, one whitespace separated token per formula
NUMERIC = {"UpperBounds", "StateSpace"}


def split_results(field, exam):
    """The per formula tokens of a contest `results` or `estimated result` field.

    Booleans come as one character per formula; the contest file sometimes
    breaks that string with a space (`F? FTTFFTFTTFTTTT`), so whitespace is
    removed first for the boolean examinations, as `csv_to_control.pl` does.
    """
    field = field.replace("(", "").replace(")", "")
    field = re.sub(r"\s+", "", field) if exam not in NUMERIC else field.strip()
    if not field:
        return []
    if " " in field:
        return field.split()
    if len(field) == 16:
        return list(field)
    return [field]


def formula_index(name):
    m = RE_INDEX.search(name)
    return int(m.group(1)) if m else 0


def family(model):
    return re.sub(r"-(PT|COL)-.*$", "", model)


class ResultSet:
    """Verdicts, run records and formula names of one tool configuration."""

    def __init__(self, name, source):
        self.name = name
        self.source = source
        self.verdicts = {}     # (model, exam, idx) -> value
        self.runs = {}         # (model, exam) -> {"time": s, "status": ..., "log": path, "extra": {}}
        self.names = {}        # (model, exam, idx) -> formula name

    def examinations(self):
        return sorted({e for _, e in self.runs})

    def instances(self, exam):
        return sorted(m for m, e in self.runs if e == exam)


def parse_log(path, extractors=()):
    """(model, exam, formula names in order, answers by name, run record)."""
    names, answers = [], {}
    model = exam = ""
    in_control = seen_syscall = False
    run = {"time": None, "status": "finished", "log": os.path.abspath(path), "extra": {}, "timeout": None}
    failure = ""
    state = [e.start() for e in extractors]
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if in_control:
                if "=" in line and not line.startswith("syscalling"):
                    names.append(line.partition("=")[0])
                    continue
                in_control = False
            if line.startswith("Control values :"):
                in_control = True
                continue
            m = RE_SYSCALL.match(line)
            if m:
                seen_syscall = True
                words = m.group(1).split()
                if len(words) >= 3:
                    model, exam = words[1], words[2]
                continue
            m = RE_TIMEOUT.match(line)
            if m:
                run["timeout"] = int(m.group(1))
                continue
            if seen_syscall:
                m = RE_VERDICT.match(line)
                if m:
                    answers[m.group(1)] = normalize(m.group(2))
                    continue
            m = RE_TC_ALL.search(line)
            if m:
                run["time"] = int(m.group(1)) / 1000
            if not failure:
                for fname, pattern in FAILURES:
                    if pattern in line:
                        failure = fname
                        break
            for e, s in zip(extractors, state):
                e.line(line, s)
    for e, s in zip(extractors, state):
        run["extra"].update(e.finish(s))
    if failure:
        run["status"] = failure
    elif run["time"] is None:
        run["status"] = "truncated"
    elif run["timeout"] and run["time"] > run["timeout"] - 50:
        run["status"] = "timeout"
    return model, exam, names, answers, run


def load_logs(name, dirs, extractors=()):
    """A result set from directories of harness logs (files ending in `out` or `log`)."""
    rs = ResultSet(name, {"logs": [os.path.abspath(d) for d in dirs]})
    for d in dirs:
        files = [d] if os.path.isfile(d) else sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith("out") or f.endswith(".log"))
        for path in files:
            model, exam, names, answers, run = parse_log(path, extractors)
            if not model:
                continue
            rs.runs[(model, exam)] = run
            for fname in names:
                idx = formula_index(fname)
                rs.names[(model, exam, idx)] = fname
                if fname in answers:
                    rs.verdicts[(model, exam, idx)] = answers[fname]
    return rs


def read_raw(raw_csv):
    """Rows of raw-result-analysis.csv as dicts keyed by the columns we use."""
    with open(raw_csv, newline="") as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            yield {"tool": row[0], "model": row[1], "exam": row[2], "results": row[6],
                   "time": row[10], "status": row[12], "estimated": row[15], "backing": row[16]}


def load_contest(name, raw_csv, tool):
    """A result set for one contest tool."""
    rs = ResultSet(name, {"contest": tool, "raw": os.path.abspath(raw_csv)})
    for r in read_raw(raw_csv):
        if r["tool"] != tool:
            continue
        key = (r["model"], r["exam"])
        rs.runs[key] = {"time": float(r["time"] or 0) / 1000, "status": "timeout" if r["status"] == "timeout" else "finished",
                        "log": None, "extra": {}, "timeout": 3600}
        for i, v in enumerate(split_results(r["results"], r["exam"])):
            if v not in NO_ANSWER:
                rs.verdicts[(r["model"], r["exam"], i)] = normalize(v)
    return rs


def load_consensus(raw_csv):
    """The field: {(model, exam, idx): value} and {(model, exam, idx): [tools backing it]}."""
    consensus, backing = {}, collections.defaultdict(list)
    tokens = {}
    for r in read_raw(raw_csv):
        key = (r["model"], r["exam"])
        if key not in tokens:
            for i, v in enumerate(split_results(r["estimated"], r["exam"])):
                if v not in NO_ANSWER:
                    consensus[(r["model"], r["exam"], i)] = normalize(v)
            tokens[key] = True
        if r["tool"] in VIRTUAL:
            continue
        for i, v in enumerate(split_results(r["results"], r["exam"])):
            if v not in NO_ANSWER:
                c = consensus.get((r["model"], r["exam"], i))
                if c is not None and normalize(v) == c:
                    backing[(r["model"], r["exam"], i)].append(r["tool"])
    return consensus, backing
