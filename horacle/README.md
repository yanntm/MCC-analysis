# Building `forms<year>.csv` and `iscex<year>.csv` without Go

These two files classify every **reachability** query (ReachabilityCardinality /
ReachabilityFireability) of an MCC edition:

* `conv/forms<year>.csv` — `<key> <AG|EF> <size>`, the formula **modality**.
* `conv/iscex<year>.csv` — `<key> <INV|CEX|UNKNOWN>`, whether the query is an
  invariant (INV), decided by a counter-example (CEX), or undecided (UNKNOWN).

`<key>` is `<ModelFamily>-<ModelType>-<ModelInstance>-<Examination>-<NN>`.

Historically these were produced by the Go tools `forms/isag.go` and
`conv/conv.go` plus `conv/iscex.sh` and a hand-curated oracle (see
`conv/HOWTO.md`). They are now produced by two Python scripts, **no Go and no
`hue` dependency**. The Go sources are kept only for reference.

## What replaced what

| old | new |
|-----|-----|
| `isag.go` (needs `dalzilio/hue`) | `buildForms.py` (stdlib `xml`, `tarfile`) |
| `conv.go` + `iscex.sh` + manual Excel oracle | `buildIsCex.py` |
| oracle verdicts from the global summary | the analysis' own per-formula `Consensus` |

## Step 1 — get the model + formula inputs

The formulas live in the per-year `pnmcc-models-<year>` repos (or directly in
`https://mcc.lip6.fr/<year>/archives/INPUTS-<year>.tar.gz`). Clone the repo and
run its `install_inputs.sh`; you end up with `website/INPUTS/` holding one
`<model>.tgz` per instance, each containing `ReachabilityCardinality.xml` and
`ReachabilityFireability.xml`.

`buildForms.py` reads those `.tgz` **directly**, so it is immune to any local
edits made to extracted folders.

## Step 2 — modality (AG/EF)

```
python3 buildForms.py -inputs ~/git/pnmcc-models-<year>/website/INPUTS -o conv/forms<year>.csv
```

Modality is the top temporal operator under `<formula>`:
`all-paths/globally` → `AG`, `exists-path/finally` → `EF`. The `size` column is a
plain XML node count (not `hue`'s `formula.Size`) and is unused downstream.

## Step 3 — INV/CEX classification

The verdict comes from the analysis pipeline's fine-grained `Consensus` column in
`website/<year>/reachability/resolution.csv` (built by `buildRefinedResults.R`),
**not** from a separate oracle:

```
python3 buildIsCex.py -forms conv/forms<year>.csv \
    -resolution ../website/<year>/reachability/resolution.csv \
    -o conv/iscex<year>.csv
```

Truth table (modality × Consensus):

```
AG & TRUE  -> INV      EF & TRUE  -> CEX
AG & FALSE -> CEX      EF & FALSE -> INV
no consensus, or unknown modality -> UNKNOWN
```

Queries with no consensus verdict (tools disagreed / `?`) are absent from
`resolution.csv` and therefore land in `UNKNOWN`, matching the old behaviour.

## Wiring into the pipeline

`runAnalysis.sh` already copies `conv/iscex<year>.csv` to `iscex.csv` for the
year being processed, and `fuseFormulaType.R` joins it onto the reachability
results. So once `iscex<year>.csv` exists here, nothing else changes.
