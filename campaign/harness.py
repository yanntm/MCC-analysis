"""What every run_test.pl log carries, shared by the classic and the total loaders."""

import re

RE_SYSCALL = re.compile(r"^syscalling : (.*)$")
RE_TIMEOUT = re.compile(r"^Timeout set at :(\d+) seconds")
RE_TC = re.compile(r"##teamcity\[(\w+) name='([^']*)'(?:.*?duration='(\d+)')?")
RE_WALK = re.compile(r"^PetriSpot walker: (\d+)/(\d+) properties solved"
                     r"(?:, \d+ bounds reported)? in (\d+) ms \(exit (-?\d+)\)")

# the first pattern found names the failure of a run that produced nothing
FAILURES = [
    ("no_input", "Cannot open file"),
    ("overlarge_marking", "OverlargeMarkingException"),
    ("eclipse_fatal", "An error has occurred. See the log file"),
    ("out_of_memory", "OutOfMemoryError"),
    ("its_abort", "terminate called"),
]


def failure_of(line):
    for name, pattern in FAILURES:
        if pattern in line:
            return name
    return ""


def status_of(failure, time, timeout):
    """finished, timeout, truncated (no trailer) or the failure name."""
    if failure:
        return failure
    if time is None:
        return "truncated"
    if timeout and time > timeout - 50:
        return "timeout"
    return "finished"


def family(model):
    return re.sub(r"-(PT|COL)-.*$", "", model)


def natural_key(s):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", s)]
