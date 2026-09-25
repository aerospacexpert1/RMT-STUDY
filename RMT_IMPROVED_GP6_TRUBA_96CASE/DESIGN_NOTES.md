# RMT_IMPROVED_GP6 design notes

## Provenance

The reacting-flow source was generated directly from the exact frozen V95
SG-RBGS production source stored at:

`aerospacexpert1/robust-multigrid-reactive-flow-mms`
branch `mms-benchmarks-v4`

`_reference_sources/SG_RBGS_TRUBA_96CASE/SG_RBGS_TRUBA_96CASE/src/opposedflow_sg_rbgs.c`

The 96-case manifest was reconstructed exactly from the completed
`RMT_FINALVOL2_campaign_summary.csv` in `aerospacexpert1/RMT-STUDY`.

## Reason for GP6

The baseline RMT_FINALVOL2 campaign reports 16 smoothing sweeps.  The improved
variant deliberately tests a lower fixed post-smoothing budget of 6 while
preserving the same stopping tolerances.  This isolates whether the previously
observed low RMT cycle count was purchased with excessive cycle work.

## Parallel structure

A single OpenMP team is created for geometric work. Independent shifted-grid
branches are tasks down to `rmtTaskDepth`. The finest correction grid is then
post-smoothed with parallel RBGS. This avoids nested OpenMP teams and
oversubscription.

## Shift-aware side boundary treatment

For a homogeneous Dirichlet correction and a shifted coarse cell centre at
distance d from the physical boundary with coarse spacing H, the ghost value is

`c_g = -(1-xi)/xi * c_1`, where `xi=d/H`.

At the finest cell-centred grid, xi=1/2 and the familiar `c_g=-c_1` is
recovered. Top/bottom pressure patches are homogeneous Neumann corrections.

## Transparency diagnostics

The summary records:
- shifted branch count;
- spawned OpenMP task count;
- terminal coarse solves and CG iterations;
- line-search backtracks;
- emergency RBGS fallback sweeps;
- RMT point updates.

These diagnostics are intended to distinguish algorithmic convergence from
cycle cost and implementation overhead.
