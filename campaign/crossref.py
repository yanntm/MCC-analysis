"""Cross-references between result sets on one examination.

Against the field: every value of a set is `ok` (equals the consensus),
`wrong` (differs from a known consensus), `bonus` (the consensus has none);
every consensus value a set lacks is `missed`. Between two sets: values
`both` have and agree on, `disagree` on, `onlyA`, `onlyB`, and `neither`
over the union of formulas either set knows of.
"""

import collections
import statistics

from resultsets import family


def keys_of(sets, consensus, exam):
    """Every (model, idx) any set or the consensus has a formula for, per instance."""
    keys = set()
    for rs in sets:
        keys |= {(m, i) for (m, e, i) in rs.names if e == exam}
        keys |= {(m, i) for (m, e, i) in rs.verdicts if e == exam}
    keys |= {(m, i) for (m, e, i) in consensus if e == exam}
    return sorted(keys)


def status(value, cons):
    if value is None:
        return "missed" if cons is not None else "none"
    if cons is None:
        return "bonus"
    return "ok" if value == cons else "wrong"


def summary(rs, exam, consensus, keys):
    """The field census of one set on one examination."""
    c = collections.Counter()
    for m, i in keys:
        c[status(rs.verdicts.get((m, exam, i)), consensus.get((m, exam, i)))] += 1
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
    for m, i in keys:
        va, vb = a.verdicts.get((m, exam, i)), b.verdicts.get((m, exam, i))
        if va is None and vb is None:
            c["neither"] += 1
        elif va is None:
            c["onlyB"] += 1
        elif vb is None:
            c["onlyA"] += 1
        elif va == vb:
            c["both"] += 1
        else:
            c["disagree"] += 1
    return dict(c)


def instance_rows(sets, exam, consensus, keys):
    """One row per instance: per set the answered count, ok count, time, status, log."""
    by_model = collections.defaultdict(list)
    for m, i in keys:
        by_model[m].append(i)
    rows = []
    for m, idxs in sorted(by_model.items()):
        row = {"model": m, "family": family(m), "formulas": len(idxs),
               "known": sum(1 for i in idxs if (m, exam, i) in consensus), "sets": {}}
        for rs in sets:
            run = rs.runs.get((m, exam))
            answered = sum(1 for i in idxs if (m, exam, i) in rs.verdicts)
            ok = sum(1 for i in idxs if rs.verdicts.get((m, exam, i)) is not None and rs.verdicts.get((m, exam, i)) == consensus.get((m, exam, i)))
            wrong = sum(1 for i in idxs if rs.verdicts.get((m, exam, i)) is not None and consensus.get((m, exam, i)) is not None and rs.verdicts.get((m, exam, i)) != consensus.get((m, exam, i)))
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
    for m, i in keys:
        name = next((rs.names.get((m, exam, i)) for rs in sets if (m, exam, i) in rs.names), None) or f"{m}-{exam}-{i:02d}"
        cons = consensus.get((m, exam, i))
        row = {"model": m, "idx": i, "name": name, "cons": cons, "who": backing.get((m, exam, i), []), "vals": {}}
        for rs in sets:
            v = rs.verdicts.get((m, exam, i))
            row["vals"][rs.name] = [v, status(v, cons)]
        rows.append(row)
    return rows


def crossref(sets, exam, consensus, backing):
    keys = keys_of(sets, consensus, exam)
    present = [rs for rs in sets if any(e == exam for _, e in rs.runs)]
    return {
        "examination": exam,
        "sets": [rs.name for rs in present],
        "summary": [summary(rs, exam, consensus, keys) for rs in present],
        "pairs": {f"{a.name}|{b.name}": pair(a, b, exam, keys) for a in present for b in present if a is not b},
        "instances": instance_rows(present, exam, consensus, keys),
        "values": value_rows(present, exam, consensus, backing, keys),
    }
