# RMT_IMPROVED — 96-case reacting-flow campaign

This branch is a controlled optimization of the validated FINALVOL2 RMT pressure
solver.  The reacting-flow physics, V95 timestep loop, pressure equation,
pressure tolerances, scalar treatment, meshes, chemistry classes and thread
counts are intentionally unchanged.

The production solver label is **RMT_IMPROVED**.

## Frozen numerical configuration

All 96 production cases use one globally fixed RMT configuration:

```text
factor-three shifted-grid hierarchy
coarsest-to-finest sawtooth
presmoothing = 0
postsmoothing = 16
correction factor = 1
coarsest solve = direct
case-specific tuning = none
```

The 16 post-sweeps are intentionally frozen for the entire campaign and are not
selected by velocity, chemistry class, mesh, or thread count.  A pre-production
mesh-ladder screen tested 6, 8, 10, 12, 14, 16, 18, 20 and 24 global post-sweep
counts.  Counts below 16 did not satisfy the existing robustness/mesh-ladder
gate: 6--12 became unstable on sufficiently fine meshes and 14 converged but
lost the required mesh-independent cycle behavior.  Sixteen is therefore kept
as the minimum configuration that passes the previously defined validation
gate.  The improved campaign changes implementation cost, not the validated
numerical RMT cycle.

## Implementation improvements

The mathematical RMT correction remains factor-three, multiple-coarse-grid and
full-correction.  The implementation now removes avoidable execution overhead:

1. The fine-grid defect integral is formed once per RMT cycle.
2. The integral image is built with a two-pass OpenMP implementation.
3. Shifted-grid finite-volume coefficients are precomputed.
4. Red/black point maps are grouped by independent shifted-grid family.
5. Smoothing uses a hybrid parallel strategy:
   - **algebraic parallelism** on fine levels, where the OpenMP team cooperates
     on red and black point sets inside one persistent parallel region;
   - **geometric parallelism** on deeper levels, where complete independent
     shifted grids are assigned to threads, eliminating global red/black
     barriers between unrelated grids.
6. Invariant coarsest matrices retain cached LU factorizations and every current
   RHS is solved directly.

No interpolation, line search, hidden SG fallback, mesh-specific smoother
selection, or physics-specific RMT branch is introduced.

## Scientific comparison rule

Do not merge these results into the previous RMT_FINALVOL2 summary under the
same solver name.  Treat **RMT_IMPROVED** as an additional solver configuration.
The purpose is to measure whether reducing excessive post-smoothing work and
exposing both geometric and algebraic parallelism improves time-to-solution
without changing the frozen reacting-flow problem.

## Validation gates

`./build.sh` must pass all of the following before the 96-case array is
released:

- frozen-V95 fairness audit;
- calibration/production separation audit;
- boundary control-volume restriction test;
- manufactured pressure mesh ladder at **16 post-sweeps**;
- correction equivalence against the previous RMT implementation at the same
  16-sweep count (roundoff tolerance);
- production solver compilation.

The gated submit script then runs two representative cases before releasing the
full array.

## TRUBA

```bash
chmod +x build.sh rebuild_manifest.sh run_case.sh submit_gated_96.sh
./rebuild_manifest.sh
./submit_gated_96.sh
```

The full campaign is 96 cases:

- 6 physical labels;
- M1–M4 meshes;
- 1, 2, 4 and 16 OpenMP threads.

The Slurm array is `0-95%3` with a three-day wall-time limit per array task.
