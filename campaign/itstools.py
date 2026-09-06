"""Log extractors specific to ITS-Tools and its PetriSpot walker.

An extractor has `start()` returning a mutable state, `line(line, state)`
called on every log line, and `finish(state)` returning the columns to add
to the run's `extra`. `resultsets.load_logs` takes a list of them; a
competitor's logs simply get none.
"""

import re

RE_WALK = re.compile(r"^PetriSpot walker: (\d+)/(\d+) properties solved"
                     r"(?:, \d+ bounds reported)? in (\d+) ms \(exit (-?\d+)\)")
RE_VERSION = re.compile(r"^Running Version (\S+)")


class WalkerCounters:
    """Invocations of PetriSpot (invariants) and the walker census."""

    def start(self):
        return {"petrispot": 0, "walk calls": 0, "walk asked": 0, "walk solved": 0, "walk s": 0.0, "version": ""}

    def line(self, line, s):
        if line.startswith("Running PetriSpot"):
            s["petrispot"] += 1
            return
        m = RE_WALK.match(line)
        if m:
            s["walk calls"] += 1
            s["walk asked"] += int(m.group(2))
            s["walk solved"] += int(m.group(1))
            s["walk s"] += int(m.group(3)) / 1000
            return
        m = RE_VERSION.match(line)
        if m:
            s["version"] = m.group(1)

    def finish(self, s):
        s["walk s"] = round(s["walk s"], 1)
        return s


EXTRACTORS = [WalkerCounters()]
