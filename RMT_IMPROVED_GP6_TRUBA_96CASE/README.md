# RMT_IMPROVED_GP6_TRUBA_96CASE

Experimental improved RMT pressure-solver campaign built on the **frozen V95
reacting-flow production source** used by the SG-RBGS/MG comparison campaigns.

This directory is intentionally separate from the thesis baseline
`RMT_FINALVOL2`. It does not overwrite previous results.

## What changed

Only the pressure linear solver was changed. Physics, chemistry, transport,
time integration, pressure RHS, velocity/face-flux correction, output,
96-case matrix and convergence tolerances are inherited from the frozen V95
production line.

The improved pressure solver uses:

1. factor-three coarsening and all 3x3 shifted coarse-grid families;
2. sawtooth RMT traversal with no presmoothing;
3. **6 post-smoothing RBGS sweeps** by default;
4. shift-aware homogeneous pressure-correction boundary conditions;
5. OpenMP **geometric task parallelism** through shifted-grid branches
   (`rmtTaskDepth=2`);
6. OpenMP algebraic RBGS parallelism on the finest correction grid;
7. a strict small-grid matrix-free CG terminal solve instead of a large fixed
   coarse smoothing budget;
8. full RMT correction first, with monotone backtracking only when required;
9. explicit diagnostics for task count, coarse solves, backtracking,
   fallback RBGS sweeps and RMT point updates.

## Production controls

- RMT post-smoothing sweeps: 6
- maximum RMT cycles per pressure solve: 500
- maximum hierarchy depth: 8
- geometric task depth: 2
- terminal CG max iterations: 64
- terminal relative tolerance: 1e-11
- correction omega start: 1.0
- maximum backtracks: 10
- pressure relative tolerance: 1e-4
- pressure absolute tolerance: 1e-6

The 96-case campaign is the same matrix used by the frozen production studies:
6 physical labels x 4 meshes x 4 thread counts = 96 cases.

## One-command gated launch on TRUBA

```bash
chmod +x *.sh
./submit_gated_96.sh
```

This submits:

1. a debug-partition compile + 16-thread short smoke test;
2. the 96-case production array only after the preflight succeeds;
3. a second rescue array after the primary campaign. Completed cases are
   skipped by `RUN_COMPLETE`;
4. an automatic postprocess job that writes `campaign_summary.csv`.

Monitor with:

```bash
squeue -u "$USER"
./check_campaign_status.sh
./list_unfinished.sh
```

After completion:

```bash
python3 collect_summary.py
wc -l campaign_summary.csv
```

Expected final summary: 96 data rows plus one header (97 lines).

## Scientific status

This is an **experimental optimization campaign**, not a replacement for the
baseline RMT campaign. Any thesis comparison should report it separately as an
improved/geometric-parallel RMT variant and retain the original RMT results.

The emergency fine-grid RBGS safeguard is explicitly counted in
`diag_fallback_rbgs_sweeps`. Ideally it remains zero or negligible. If it is
used frequently, the run should be interpreted as a hybrid safeguarded variant,
not a pure RMT cycle.
