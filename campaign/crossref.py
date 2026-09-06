"""Cross-references between result sets on one examination.

Against the field (the oracle files): every value of a set is `ok` (equals the consensus),
`wrong` (differs from a known consensus), `bonus` (the consensus has none);
every consensus value a set lacks is `missed`. Between two sets: values
`both` have and agree on, `disagree` on, `onlyA`, `onlyB`, and `neither`
over the union of formulas either set knows of.
"""

import collections
import statistics

from harness import family


def keys_of(sets, oracle, exam):
    """Every (model, formula name) the oracle or any set has, in the oracle's order."""
    keys = []
    seen = set()
    for src in [oracle] + sets:
        for (m, e), names in src.names.items():
            if e != exam:
                continue
            for n in names:
                if (m, n) not in seen:
                    seen.add((m, n))
                    keys.append((m, n))
    for rs in sets:
        for (m, e, n) in rs.verdicts:
            if e == exam and (m, n) not in seen:
                seen.add((m, n))
                keys.append((m, n))
    return sorted(keys)


def same(a, b):
    """Equal verdicts; numbers within a relative 1e-3, the raw results shorten large ones (StateSpace)."""
    if a == b:
        return True
    try:
        x, y = float(a), float(b)
    except ValueError:
        return False
    return abs(x - y) <= 1e-3 * max(abs(x), abs(y))


def status(value, cons):
    if value is None:
        return "missed" if cons is not None else "none"
    if cons is None:
        return "bonus"
    return "ok" if same(value, cons) else "wrong"


def summary(rs, exam, consensus, keys):
    """The field census of one set on one examination."""
    c = collections.Counter()
    for m, n in keys:
        c[status(rs.verdicts.get((m, exam, n)), consensus.get((m, exam, n)))] += 1
    runs = [r for (m, e), r in rs.runs.items() if e == exam]
    times = [r["time"] for r in runs if r["time"] is not None]
    st = collections.Counter(r["status"] for r in runs)
    return {"set": rs.name, "runs": len(runs), "answered": c["ok"] + c["wrong"] + c["bonus"],
            "ok": c["ok"], "wrong": c["wrong"], "missed": c["missed"], "bonus": c["bonus"],
            "timeouts": st["timeout"], "failures": sum(v for k, v in st.items() if k not in ("finished", "timeout")),
            "median s": round(statistics.median(times), 1) if times else None,
            "total h": round(sum(times) / 3600, 1) if times else 0}


def pair(a, b, exam, keys):
    """The five way split of two sets' values."""
    c = collections.Counter()
    for m, n in keys:
        va, vb = a.verdicts.get((m, exam, n)), b.verdicts.get((m, exam, n))
        if va is None and vb is None:
            c["neither"] += 1
        elif va is None:
            c["onlyB"] += 1
        elif vb is None:
            c["onlyA"] += 1
        elif same(va, vb):
            c["both"] += 1
        else:
            c["disagree"] += 1
    return dict(c)


def instance_rows(sets, exam, consensus, keys):
    """One row per instance: per set the answered count, ok count, time, status, log."""
    by_model = collections.defaultdict(list)
    for m, n in keys:
        by_model[m].append(n)
    rows = []
    for m, names in sorted(by_model.items()):
        row = {"model": m, "family": family(m), "formulas": len(names),
               "known": sum(1 for n in names if (m, exam, n) in consensus), "sets": {}}
        for rs in sets:
            run = rs.runs.get((m, exam))
            st = [status(rs.verdicts.get((m, exam, n)), consensus.get((m, exam, n))) for n in names]
            answered = sum(1 for x in st if x in ("ok", "wrong", "bonus"))
            ok = st.count("ok")
            wrong = st.count("wrong")
            row["sets"][rs.name] = {"answered": answered, "ok": ok, "wrong": wrong,
                                    "time": None if run is None else run["time"],
                                    "status": None if run is None else run["status"],
                                    "log": None if run is None else run["log"],
                                    "extra": {} if run is None else run["extra"]}
        rows.append(row)
    return rows


def value_rows(sets, exam, consensus, backing, keys):
    """One row per formula: the consensus, who backs it, and every set's value."""
    rows = []
    for m, n in keys:
        cons = consensus.get((m, exam, n))
        row = {"model": m, "name": n, "cons": cons, "who": backing.get((m, exam, n), []), "vals": {}}
        for rs in sets:
            v = rs.verdicts.get((m, exam, n))
            row["vals"][rs.name] = [v, status(v, cons)]
        rows.append(row)
    return rows


def crossref(sets, exam, oracle):
    consensus, backing = oracle.values, oracle.backing
    keys = keys_of(sets, oracle, exam)
    # a set with runs but no verdict on this examination did not compete in it
    present = [rs for rs in sets if any(e == exam for _, e in rs.runs) and any(e == exam for (_, e, _) in rs.verdicts)]
    return {
        "examination": exam,
        "sets": [rs.name for rs in present],
        "summary": [summary(rs, exam, consensus, keys) for rs in present],
        "pairs": {f"{a.name}|{b.name}": pair(a, b, exam, keys) for a in present for b in present if a is not b},
        "instances": instance_rows(present, exam, consensus, keys),
        "values": value_rows(present, exam, consensus, backing, keys),
    }
