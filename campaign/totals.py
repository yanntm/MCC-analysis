"""The total examinations: QuasiLivenessAll, StableMarkingAll, UpperBoundsAll.

One question per transition or per place; the tool prints `TOTAL <exam> <n>`
then one line per atom as it settles, `QLIVE t12 TRUE <techniques>`,
`STABLE p3 FALSE ...`, `BOUND p3 7 ...`, and `BOUND p3 ? lo hi` while a bound
is open. There is no contest reference: a run is read for its completion,
the split between witnessed and proved atoms, the engine that closed each,
the time at which a quarter, half, three quarters and all were closed, and
its vector, kept so that two runs of the same instance can be compared atom
by atom. The vector also implies the global QuasiLiveness (an F: FALSE, all
T: TRUE) or StableMarking verdict (a T: TRUE, all F: FALSE), which the
consensus oracle can confirm or contradict.
"""

import collections
import os
import re

import harness

EXAMS = ("QuasiLivenessAll", "StableMarkingAll", "UpperBoundsAll")
RE_HEADER = re.compile(r"^TOTAL (\w+) (\d+)")
RE_ATOM = re.compile(r"^(QLIVE|STABLE|BOUND) ([pt])(\d+) (\S+)(.*)$")
WITNESSED = {"QuasiLivenessAll": "TRUE", "StableMarkingAll": "FALSE"}
GLOBAL = {"QuasiLivenessAll": "QuasiLiveness", "StableMarkingAll": "StableMarking"}
ENGINES = ("initial", "walk", "smt", "dd", "other")


def engine(tags):
    if "DECISION_DIAGRAMS" in tags:
        return "dd"
    if "SAT_SMT" in tags:
        return "smt"
    if "WALK" in tags:
        return "walk"
    if "INITIAL_STATE" in tags:
        return "initial"
    return "other"


def parse(path, extractors=()):
    """(model, exam, record) of one total examination log, or (None, None, None)."""
    model = exam = ""
    atoms = 0
    verdict = {}
    open_bounds = set()
    when = []
    clock = 0
    time = None
    timeout = None
    failure = ""
    last = ""
    trailer = False
    walk = [0, 0, 0.0]
    state = [e.start() for e in extractors]
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = harness.RE_SYSCALL.match(line)
            if m:
                words = m.group(1).split()
                if len(words) >= 3:
                    model, exam = words[1], words[2]
                continue
            m = harness.RE_TIMEOUT.match(line)
            if m:
                timeout = int(m.group(1))
                continue
            m = RE_HEADER.match(line)
            if m:
                atoms = int(m.group(2))
                continue
            m = RE_ATOM.match(line)
            if m:
                idx, value, tags = int(m.group(3)), m.group(4), m.group(5)
                if value == "?":
                    if idx not in verdict:
                        open_bounds.add(idx)
                elif idx not in verdict:
                    verdict[idx] = (value, engine(tags))
                    open_bounds.discard(idx)
                    when.append(clock)
                continue
            if line.startswith("TIME LIMIT") or line.startswith("Actual read output values"):
                trailer = True
            if not trailer and line and not line.startswith("##teamcity") and not line.startswith(" Formula"):
                last = line[:70]
            m = harness.RE_TC.search(line)
            if m:
                kind, name, duration = m.group(1), m.group(2), m.group(3)
                if kind == "testFinished" and duration is not None:
                    if name == "all":
                        time = int(duration) / 1000
                    else:
                        # the marker of a verdict line follows it, so the clock is read late by one
                        clock += int(duration)
                        if when and when[-1] == clock - int(duration) and name != "runits":
                            when[-1] = clock
                continue
            m = harness.RE_WALK.match(line)
            if m:
                walk[0] += 1
                walk[1] += int(m.group(1))
                walk[2] += int(m.group(3)) / 1000
                continue
            if not failure:
                failure = harness.failure_of(line)
            for e, s in zip(extractors, state):
                e.line(line, s)
    if not model or exam not in EXAMS:
        return None, None, None
    census = collections.Counter(eng for _, eng in verdict.values())
    answered = len(verdict)
    rec = {"atoms": atoms, "answered": answered, "completion": round(answered / atoms, 4) if atoms else 0.0,
           "witnessed": sum(1 for v, _ in verdict.values() if v == WITNESSED.get(exam)),
           "open": len(open_bounds), "engines": {k: census.get(k, 0) for k in ENGINES},
           "time": time, "status": harness.status_of(failure, time, timeout), "log": os.path.abspath(path),
           "walk calls": walk[0], "walk solved": walk[1], "walk s": round(walk[2], 1), "last": last,
           "vector": {i: v for i, (v, _) in verdict.items()}}
    rec["proved"] = answered - rec["witnessed"] if exam in WITNESSED else 0
    for q, col in ((0.25, "t25"), (0.5, "t50"), (0.75, "t75"), (1.0, "t100")):
        need = int(atoms * q + 0.999999) if atoms else 0
        rec[col] = when[need - 1] / 1000 if need and answered >= need else None
    extra = {}
    for e, s in zip(extractors, state):
        extra.update(e.finish(s))
    rec["extra"] = extra
    return model, exam, rec


def implied(exam, rec):
    """The global verdict a vector implies, or None."""
    values = set(rec["vector"].values())
    complete = rec["answered"] == rec["atoms"] and rec["atoms"] > 0
    if exam == "QuasiLivenessAll":
        return "FALSE" if "FALSE" in values else ("TRUE" if complete else None)
    if exam == "StableMarkingAll":
        return "TRUE" if "TRUE" in values else ("FALSE" if complete else None)
    return None


def pair(a, b):
    """Agreement of two vectors of the same instance."""
    c = collections.Counter()
    for i in set(a) | set(b):
        va, vb = a.get(i), b.get(i)
        if va is None:
            c["onlyB"] += 1
        elif vb is None:
            c["onlyA"] += 1
        elif va == vb:
            c["both"] += 1
        else:
            c["disagree"] += 1
    return c


def summary(rs, exam, oracle):
    runs = [(m, r) for (m, e), r in rs.totals.items() if e == exam]
    atoms = sum(r["atoms"] for _, r in runs)
    answered = sum(r["answered"] for _, r in runs)
    eng = collections.Counter()
    for _, r in runs:
        eng.update(r["engines"])
    check = collections.Counter(consistency(exam, m, r, oracle) for m, r in runs)
    times = [r["time"] for _, r in runs if r["time"] is not None]
    return {"set": rs.name, "runs": len(runs), "atoms": atoms, "answered": answered,
            "completion": round(answered / atoms, 4) if atoms else 0,
            "complete": sum(1 for _, r in runs if r["atoms"] and r["answered"] == r["atoms"]),
            "timeouts": sum(1 for _, r in runs if r["status"] == "timeout"),
            "failures": sum(1 for _, r in runs if r["status"] not in ("finished", "timeout")),
            "witnessed": sum(r["witnessed"] for _, r in runs), "proved": sum(r["proved"] for _, r in runs),
            "open bounds": sum(r["open"] for _, r in runs),
            "engines": " ".join(f"{k} {eng[k]}" for k in ENGINES),
            "confirmed": check["confirmed"], "contradicted": check["CONTRADICTION"],
            "total h": round(sum(times) / 3600, 1), "walker h": round(sum(r["walk s"] for _, r in runs) / 3600, 1)}


def consistency(exam, model, rec, oracle):
    g = GLOBAL.get(exam)
    if g is None:
        return ""
    ours = implied(exam, rec)
    theirs = oracle.value(model, g, g) if oracle else None
    if ours is None:
        return "undecided"
    if theirs is None:
        return "consensus unknown"
    return "confirmed" if ours == theirs else "CONTRADICTION"


def page_data(sets, exam, oracle):
    present = [rs for rs in sets if any(e == exam and r["answered"] > 0 for (_, e), r in rs.totals.items())]
    models = sorted({m for rs in present for (m, e) in rs.totals if e == exam}, key=harness.natural_key)
    runs = []
    for m in models:
        row = {"model": m, "family": harness.family(m), "sets": {}}
        for rs in present:
            r = rs.totals.get((m, exam))
            if r is None:
                continue
            x = {k: v for k, v in r.items() if k != "vector"}
            x["implied"] = implied(exam, r)
            x["check"] = consistency(exam, m, r, oracle)
            row["sets"][rs.name] = x
        row["atoms"] = max((r.get("atoms", 0) for r in row["sets"].values()), default=0)
        runs.append(row)
    pairs = {}
    for a in present:
        for b in present:
            if a is b:
                continue
            c = collections.Counter()
            shared = 0
            for (m, e), ra in a.totals.items():
                rb = b.totals.get((m, e))
                if e == exam and rb is not None:
                    shared += 1
                    c.update(pair(ra["vector"], rb["vector"]))
            pairs[f"{a.name}|{b.name}"] = dict(c, shared=shared)
    fams = collections.defaultdict(list)
    for row in runs:
        fams[row["family"]].append(row["model"])
    families = [{"family": f, "instances": sorted(ms, key=harness.natural_key)} for f, ms in sorted(fams.items())]
    return {"examination": exam, "sets": [rs.name for rs in present],
            "summary": [summary(rs, exam, oracle) for rs in present], "pairs": pairs, "runs": runs, "families": families}
