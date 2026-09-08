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

`load_oracle(dir)` reads the oracle files of `pnmcc-models-2026`
(`<model>-<ABBREV>.out`, one FORMULA or STATE_SPACE line per formula with the
consensus value and, in TECHNIQUES, the tools that produced it): the formula
names in their order, which is what the contest's positional tokens are
mapped onto, and the field the "missed / bonus / wrong" vocabulary is defined
against. Every key is (model, examination, formula name).
"""

import collections
import csv
import glob
import json
import os
import re

import harness
import totals

RE_VERDICT = re.compile(r"^(?:FORMULA|STATE_SPACE)\s+(\S+)\s+(\S+)")
RE_TC_ALL = re.compile(r"##teamcity\[testFinished name='all'.*?duration='(\d+)'")

NO_ANSWER = {"DNC", "DNF", "CC", "?", ""}
VECTOR_EXAMS = {"QuasiLivenessAll", "StableMarkingAll", "UpperBoundsAll"}
VIRTUAL = {"BVT-2026", "BVT-2025", "BVT-2024"}

def unreadable(v):
    """A contest token the raw file could not carry: a huge count printed as `+Inf********`."""
    return "*" in v


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


class ResultSet:
    """Verdicts, run records and formula names of one tool configuration."""

    def __init__(self, name, source):
        self.name = name
        self.source = source
        self.verdicts = {}     # (model, exam, name) -> value
        self.runs = {}         # (model, exam) -> {"time": s, "status": ..., "log": path, "extra": {}}
        self.names = {}        # (model, exam) -> [formula names in order]
        self.totals = {}       # (model, exam) -> record of a total examination run (totals.py)

    def examinations(self):
        return sorted({e for _, e in self.runs} | {e for _, e in self.totals})

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
            m = harness.RE_SYSCALL.match(line)
            if m:
                seen_syscall = True
                words = m.group(1).split()
                if len(words) >= 3:
                    model, exam = words[1], words[2]
                continue
            m = harness.RE_TIMEOUT.match(line)
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
                failure = harness.failure_of(line)
            for e, s in zip(extractors, state):
                e.line(line, s)
    for e, s in zip(extractors, state):
        run["extra"].update(e.finish(s))
    run["status"] = harness.status_of(failure, run["time"], run["timeout"])
    return model, exam, names, answers, run


def is_total_log(path):
    """The harness names the total examination in the first lines of the log."""
    with open(path, errors="replace") as f:
        head = f.read(2000)
    return any(f"-{abbrev}-" in head or f"-{abbrev}\n" in head or f"-{abbrev} " in head for abbrev in ("QLA", "SMA", "UBA")) and "total examination" in head


CACHE_NAME = ".campaign-cache.csv"
CACHE_VERSION = "1"
CACHE_FIELDS = ["log", "mtime", "size", "kind", "model", "exam", "names", "answers",
                "time", "status", "timeout", "extra"]


def cache_signature(extractors):
    """What the cache was written with: a parser change or a different set of
    extractors invalidates it."""
    return CACHE_VERSION + "|" + ",".join(sorted(type(e).__name__ for e in extractors))


def read_cache(directory, signature):
    """Cached rows of a log directory, by absolute path, dropping any whose
    file has changed. Logs are only ever added, so an untouched file's row
    stands; a deleted one simply never gets asked for."""
    path = os.path.join(directory, CACHE_NAME)
    if not os.path.exists(path):
        return {}
    rows = {}
    try:
        with open(path, newline="") as f:
            reader = csv.reader(f)
            head = next(reader, None)
            if not head or head[0] != signature:
                return {}
            for row in reader:
                if len(row) != len(CACHE_FIELDS):
                    continue
                r = dict(zip(CACHE_FIELDS, row))
                try:
                    if os.path.getmtime(r["log"]) != float(r["mtime"]) or os.path.getsize(r["log"]) != int(r["size"]):
                        continue
                except OSError:
                    continue
                rows[r["log"]] = r
    except (OSError, csv.Error):
        return {}
    return rows


def write_cache(directory, signature, rows):
    """Rewrite a directory's cache; failure is not fatal, it only costs a
    reparse next time."""
    path = os.path.join(directory, CACHE_NAME)
    try:
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow([signature] + CACHE_FIELDS[1:])
            for r in rows.values():
                w.writerow([r[k] for k in CACHE_FIELDS])
    except OSError:
        pass


def cacheable(names, answers):
    """A verdict round-trips through the cache only if it has no whitespace or
    separator of ours; MCC names and verdicts never do, but do not assume it."""
    for n in names:
        if not n or any(c in n for c in " \t=") :
            return False
    for k, v in answers.items():
        if any(c in str(k) + str(v) for c in " \t="):
            return False
    return True


def row_of(path, kind, model, exam, names, answers, run):
    return {"log": os.path.abspath(path), "mtime": repr(os.path.getmtime(path)),
            "size": str(os.path.getsize(path)), "kind": kind, "model": model, "exam": exam,
            "names": " ".join(names), "answers": " ".join(f"{k}={v}" for k, v in answers.items()),
            "time": "" if run.get("time") is None else repr(run["time"]),
            "status": run.get("status", "finished"),
            "timeout": "" if run.get("timeout") is None else str(run["timeout"]),
            "extra": json.dumps(run.get("extra", {}), sort_keys=True)}


def parsed_of(row):
    """(model, exam, names, answers, run) back from a cached row."""
    names = row["names"].split() if row["names"] else []
    answers = {}
    for token in row["answers"].split():
        k, _, v = token.partition("=")
        answers[k] = v
    run = {"time": float(row["time"]) if row["time"] else None,
           "status": row["status"], "log": row["log"],
           "extra": json.loads(row["extra"]) if row["extra"] else {},
           "timeout": int(row["timeout"]) if row["timeout"] else None}
    return row["model"], row["exam"], names, answers, run


def load_logs(name, patterns, extractors=()):
    """A result set from directories of harness logs (files ending in `out` or `log`).

    Each pattern is a directory, a file, or a glob such as `/data/run/2026-09-06/*`;
    directories without logs are skipped, so a campaign folder can be named whole.
    Runs of the total examinations go to `totals`, the others to `runs`.
    """
    dirs = sorted(p for pat in patterns for p in (glob.glob(pat) or [pat]))
    rs = ResultSet(name, {"logs": []})
    for d in dirs:
        before = len(rs.runs) + len(rs.totals)
        if os.path.isfile(d):
            files = [d]
        elif os.path.isdir(d):
            files = sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith("out") or f.endswith(".log"))
        else:
            continue
        signature = cache_signature(extractors)
        cache = read_cache(d, signature) if os.path.isdir(d) else {}
        fresh = dict(cache)
        added = 0
        for path in files:
            if is_total_log(path):
                # the total examinations keep their own record shape; they are
                # few and are not cached here
                model, exam, rec = totals.parse(path, extractors)
                if model:
                    rs.totals[(model, exam)] = rec
                continue
            hit = cache.get(os.path.abspath(path))
            if hit is not None and hit["kind"] == "run":
                model, exam, names, answers, run = parsed_of(hit)
            else:
                model, exam, names, answers, run = parse_log(path, extractors)
                if model and cacheable(names, answers):
                    fresh[os.path.abspath(path)] = row_of(path, "run", model, exam, names, answers, run)
                    added += 1
            if not model or exam in VECTOR_EXAMS:
                continue
            rs.runs[(model, exam)] = run
            rs.names[(model, exam)] = names
            for fname in names:
                if fname in answers:
                    rs.verdicts[(model, exam, fname)] = answers[fname]
        if added and os.path.isdir(d):
            write_cache(d, signature, fresh)
        if len(rs.runs) + len(rs.totals) > before:
            # only the directories that held runs are log roots for serve.py
            rs.source["logs"].append(os.path.abspath(d))
    return rs


def read_raw(raw_csv):
    """Rows of raw-result-analysis.csv as dicts keyed by the columns we use."""
    with open(raw_csv, newline="") as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            yield {"tool": row[0], "model": row[1], "exam": row[2], "results": row[6],
                   "time": row[10], "status": row[12], "estimated": row[15], "backing": row[16]}


CONTEST_CACHE_VERSION = "1"
CONTEST_FIELDS = ["model", "exam", "time", "status", "values"]


def contest_cache_path(raw_csv, tool):
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", tool)
    return f"{os.path.abspath(raw_csv)}.{safe}.cache.csv"


def contest_signature(raw_csv, tool):
    st = os.stat(raw_csv)
    return f"{CONTEST_CACHE_VERSION}|{tool}|{st.st_mtime!r}|{st.st_size}"


def read_contest_cache(raw_csv, tool):
    """One tool's rows, already split and normalised, or None to parse again.

    The contest table is one 50 MB file of loose text that every contest set
    reads whole and cleans field by field, which costs minutes over a handful
    of sets. What comes out of that cleaning is small and regular, so it is
    kept beside the table and reread instead, keyed on the table's own mtime
    and size.
    """
    path = contest_cache_path(raw_csv, tool)
    if not os.path.exists(path):
        return None
    try:
        with open(path, newline="") as f:
            reader = csv.reader(f)
            head = next(reader, None)
            if not head or head[0] != contest_signature(raw_csv, tool):
                return None
            return [dict(zip(CONTEST_FIELDS, row)) for row in reader if len(row) == len(CONTEST_FIELDS)]
    except (OSError, csv.Error):
        return None


def write_contest_cache(raw_csv, tool, rows):
    try:
        with open(contest_cache_path(raw_csv, tool), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow([contest_signature(raw_csv, tool)] + CONTEST_FIELDS[1:])
            for r in rows:
                w.writerow([r[k] for k in CONTEST_FIELDS])
    except OSError:
        pass


def load_contest(name, raw_csv, tool, oracle):
    """A result set for one contest tool; its positional tokens are named through the oracle."""
    rs = ResultSet(name, {"contest": tool, "raw": os.path.abspath(raw_csv)})
    rows = read_contest_cache(raw_csv, tool)
    if rows is None:
        rows = []
        for r in read_raw(raw_csv):
            if r["tool"] != tool:
                continue
            values = []
            for v in split_results(r["results"], r["exam"]):
                out = "?" if (v in NO_ANSWER or unreadable(v)) else normalize(v)
                values.append(out if " " not in str(out) else "?")
            rows.append({"model": r["model"], "exam": r["exam"],
                         "time": r["time"] or "0",
                         "status": "timeout" if r["status"] == "timeout" else "finished",
                         "values": " ".join(values)})
        write_contest_cache(raw_csv, tool, rows)
    # the names come from the oracle, never from the cache, so a changed oracle
    # is picked up without touching it
    for r in rows:
        key = (r["model"], r["exam"])
        names = oracle.names.get(key)
        if names is None:
            continue
        rs.runs[key] = {"time": float(r["time"] or 0) / 1000, "status": r["status"],
                        "log": None, "extra": {}, "timeout": 3600}
        rs.names[key] = names
        for i, v in enumerate(r["values"].split()):
            if v != "?" and i < len(names):
                rs.verdicts[(r["model"], r["exam"], names[i])] = v
    return rs


# the marker words of an oracle TECHNIQUES field that are not tools
ORACLE_MARKERS = {"TECHNIQUES", "ORACLE2026", "ORACLE2025", "ORACLE2024", "TEDD2026", "TEDD2025", "TEDD2024"}


class Oracle:
    """The consensus: formula names in order, values (None for `?`), backing tools."""

    def __init__(self, path):
        self.path = os.path.abspath(path)
        self.names = {}        # (model, exam) -> [formula names]
        self.values = {}       # (model, exam, name) -> value, absent when `?`
        self.backing = {}      # (model, exam, name) -> [tool tokens]

    def value(self, model, exam, name):
        return self.values.get((model, exam, name))


def load_oracle(path):
    """Every `<model>-<ABBREV>.out` of a directory; the vector oracles of the total examinations are skipped."""
    oracle = Oracle(path)
    for fname in sorted(os.listdir(path)):
        if not fname.endswith(".out"):
            continue
        with open(os.path.join(path, fname)) as f:
            header = f.readline().split()
            if len(header) < 2 or header[1] in VECTOR_EXAMS:
                continue
            model, exam = header[0], header[1]
            names = []
            for line in f:
                words = line.split()
                if len(words) < 3 or words[0] not in ("FORMULA", "STATE_SPACE"):
                    continue
                name, value = words[1], words[2]
                names.append(name)
                if value != "?":
                    oracle.values[(model, exam, name)] = normalize(value)
                oracle.backing[(model, exam, name)] = [w for w in words[3:] if w not in ORACLE_MARKERS]
            oracle.names[(model, exam)] = names
    return oracle


def backing_from_raw(oracle, raw_csv):
    """Fill the backing tools from the raw results when the oracle files do not name them."""
    for r in read_raw(raw_csv):
        if r["tool"] in VIRTUAL:
            continue
        names = oracle.names.get((r["model"], r["exam"]))
        if names is None:
            continue
        for i, v in enumerate(split_results(r["results"], r["exam"])):
            if v not in NO_ANSWER and i < len(names):
                key = (r["model"], r["exam"], names[i])
                if key in oracle.values and normalize(v) == oracle.values[key] and r["tool"] not in oracle.backing[key]:
                    oracle.backing[key].append(r["tool"])
