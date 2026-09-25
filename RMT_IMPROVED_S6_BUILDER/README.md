# RMT Improved S6 builder

This branch contains a **conservative overnight improvement experiment** for
the validated 96-case production RMT package.

The builder does **not** replace the production RMT implementation with a new
heap-allocating prototype.  Instead it extracts the repository's validated
`RMT_TRUBA_96CASE.rar` / RMT_FINALVOL2 package and preserves its optimized
single-workspace hierarchy and terminal-solve infrastructure.

It then makes one controlled algorithmic change:

- fixed RMT smoothing budget: **16 -> 6 sweeps**.

It also changes the solver identity to `RMT_IMPROVED_S6`, writes a patch
report, backs up every modified source text file, and creates a gated TRUBA
launch script.

Why this experiment first: completed RMT_FINALVOL2 summaries show that the
reported RMT point updates per cycle equal approximately

- M1: 48 fine-grid sweeps/cycle,
- M2: 64,
- M3/M4: 80,

which is exactly consistent with 16 smoothing sweeps across the active RMT
levels.  Reducing the fixed sweep count to 6 therefore directly attacks the
largest measured cycle-work term while leaving the verified production
architecture intact.

## TRUBA

From a fresh clone of branch `rmt-improved-96case`:

```bash
chmod +x RMT_IMPROVED_S6_BUILDER/*.sh
./RMT_IMPROVED_S6_BUILDER/prepare_improved_s6.sh

cd RMT_IMPROVED_S6_TRUBA_96CASE
./verify_improved_s6.sh
./submit_s6_96.sh
```

The generated preflight performs:

1. active-source audit,
2. GCC build,
3. post-build audit,
4. the package's existing smoke test.

The 96-case array is submitted only with `afterok` on that preflight.

## Important scope

This S6 campaign is deliberately separate from a deeper geometric-parallel RMT
refactor.  A deeper task-parallel refactor changes data dependencies and memory
layout and should first be checked against RMT_FINALVOL2 on pressure-only
equivalence tests before being entrusted with 96 long production runs.

For the thesis, retain the original RMT_FINALVOL2 campaign as the baseline and
report RMT_IMPROVED_S6 as an additional optimization experiment.
