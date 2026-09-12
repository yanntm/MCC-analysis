# `campaign/` — local pages over result sets

The rest of this repository analyses the published contest results. This
folder reads what a tool produced under the MCC-drivers harness, ours or any
competitor's, and cross-references it with other such runs and with the
contest. It runs locally and builds static pages that link to the log files
where they are: nothing is uploaded, no server runs.

## Result sets

A result set is one tool configuration's answers over the benchmark, a
`(model instance, examination, formula)` to verdict map, with the wall time of
every run and, for our own runs, the log. Two kinds:

* **logs**: a list of directories of `run_test.pl` logs (`OAR.<id>.stdout`),
  or globs: `"/data/ythierry/MCC26logs/itstools/<build>/*"` names a whole campaign
  folder as it comes off the cluster rsync, directories without logs (the
  warmup, the vector oracles) being skipped. The convention of
  `example.json`: the set `ITS-Tools latest` is that glob on the newest
  campaign folder, so after an rsync a rebuild shows the newest data.
  Tool agnostic: the `Control values :` block names the formulas in order, the
  `FORMULA` / `STATE_SPACE` lines are the answers, the teamcity `all` marker
  the duration; a failure signature or a missing trailer gives the run status.
  `"extractors": "itstools"` adds the ITS-Tools/PetriSpot counters (walker
  calls and seconds) as extra columns; a competitor's logs get none.
* **contest**: one tool of `raw-result-analysis.csv` (positional tokens, time,
  status). Any tool of the edition, `2025-gold` included.

The **consensus** is read from the oracle files of `pnmcc-models-2026`
(`<model>-<ABBREV>.out`, the same files the harness checks against): the
formula names in order, the value or `?`, and in TECHNIQUES the tools that
produced it. The contest's positional tokens are mapped onto those names, as
`csv_to_control.pl` does when it fills the oracles. When the oracle copy
predates the tool naming, the backing is recomputed from the raw file. The
raw file shortens large numbers and prints the largest as `+Inf********`:
numbers compare within a relative 1e-3 and starred tokens count as no
answer, a limit of the raw file, not of the tool. The consensus gives the vocabulary: a value
is `ok`, `wrong` or `bonus`, a silence is `missed` or `none`. Comparing to the field
is the main use case and gets the first table of every page; comparing two
arbitrary sets (two versions of a tool, two flag settings, a tool against a
competitor) is the second.

## Pages

`build.py config.json` writes one page per examination and an index. Each
page has, top to bottom:

1. every set against the field (answered, ok, wrong, missed, bonus, timeouts,
   failures, median and total time);
2. every pair of sets against each other (agree / A only / B only /
   disagree), a click on a cell selects the pair everywhere below;
3. the instances, one row per model instance, answered/ok and time per set, a
   `log` link where a set has one, filtered by a family regex and by a mode
   (A answered fewer than B, A hit the wall, some set is wrong);
4. a time scatter of A against B, log axes, one point per instance, coloured
   by which of the two answered more;
5. the values, one row per formula with the consensus, who backs it and each
   set's value coloured by status, filtered to disagreements, one-sided
   answers, or A's wrong / missed / bonus values.

For StateSpace, the values table has one row per model and four metric columns:
`STATES`, `TRANSITIONS`, `MAX_TOKEN_IN_PLACE`, and `MAX_TOKEN_PER_MARKING`.
Each cell shows the oracle, its backing, and selected tool A with status colours.
Changing A refreshes the values; B is used only by the comparison filters.
Value filters select models with any matching metric and retain all four metrics.

Tables are DataTables (sort, search, paging), the plot is Plotly, both from
their CDNs as the rest of this site does; the data is embedded in the page as
JSON, so the page is one file. `example.json` is the configuration of the
2026-09-06 PetriSpot campaigns against four contest tools.

A set that answered nothing on an examination did not compete in it and is
left off that page.

## The total examinations

`QuasiLivenessAll`, `StableMarkingAll` and `UpperBoundsAll` ask one question
per transition or per place (PetriSpot `TOTAL_QUERIES.md`); their logs are
recognised in the same directories and read by `totals.py`: completion,
witnessed against proved atoms, the engine per atom, the time at which a
quarter, half, three quarters and all were closed, the walker's share, the
last line before the kill. There is no contest reference, so their pages
show:

1. every set: completion, complete runs, timeouts, witnessed / proved or open
   bounds, the engine census, and the vectors' implied global QuasiLiveness or
   StableMarking verdict against the consensus (confirmed / contradicted);
2. every pair of sets atom by atom over the instances both ran: agree / A
   only / B only / disagree, a disagreement being a contradiction between two
   runs of our own tool;
3. the progression along a family: one line per set over the instances of a
   family in natural order, completion or wall time or atoms answered or
   walker seconds on y, family chosen from a dropdown;
4. completion against wall time, one point per run, sized by atoms, coloured
   by whether the walker was ever called;
5. the runs table, filtered by family and by mode (incomplete, at the wall,
   at the wall without a walk, contradicting the consensus, ended early).

## Serving, locally and through a tunnel

`serve.py` (default `/data/ythierry/MCC26logs/web`, one page set per
subfolder: `campaign/` from `build.py`, `order-sweep/` from libHSC's
`sweep_pages.py`; `--port 8080`) serves the pages and
answers `/logs/<absolute path>` and `/<page-set>/logs/<absolute path>`
(the relative links emitted by the pages) from the disk, for paths under the log
directories of the config (`roots.json`, written by `build.py`). It binds
`127.0.0.1` only. From another machine, an SSH tunnel is the door:

    ssh -N -L 8080:localhost:8080 -J <gateway> hydrogen      # then open http://localhost:8080/

Nothing is published: the pages exist on the disk of the machine that ran
the campaign and are read through the tunnel.

## Files

* `harness.py` — what every `run_test.pl` log carries (regexes, failure
  signatures, run status, families, natural order).
* `resultsets.py` — the `ResultSet` class and the two loaders, and the
  `Oracle` reader of the oracle files.
* `totals.py` — the total examinations: log parser, implied global verdict,
  pairwise agreement, page data.
* `itstools.py` — the extractors specific to ITS-Tools logs.
* `crossref.py` — the field census, the pairwise split, the instance and
  value rows of a page.
* `build.py` — config to pages, through `templates/` (Jinja2) with
  `static/app.js` (classic pages), `static/total.js` (total pages) and
  `static/campaign.css` inlined.
* `serve.py` — the localhost server for the pages and the logs.

Python 3 with jinja2; no R, no pandas.
