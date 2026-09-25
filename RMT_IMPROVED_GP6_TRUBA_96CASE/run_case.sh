#!/bin/bash
set -eo pipefail

ROOT=${ROOT:-$PWD}
INDEX=${1:?usage: run_case.sh ARRAY_INDEX}
MANIFEST="$ROOT/campaign_manifest.csv"
EXE="$ROOT/build/opposedflow_rmt_improved"

[[ -x "$EXE" ]] || { echo "ERROR: executable not found: $EXE" >&2; exit 2; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: manifest not found: $MANIFEST" >&2; exit 2; }

line=$(sed -n "$((INDEX + 2))p" "$MANIFEST")
[[ -n "$line" ]] || { echo "ERROR: manifest has no row for index $INDEX" >&2; exit 3; }

IFS=',' read -r array_index case_id study_family group_dir physical_case mesh_name Nx Ny velocity stiffness_class A beta Ta threads core_label <<< "$line"
[[ "$array_index" == "$INDEX" ]] || { echo "ERROR: manifest/index mismatch" >&2; exit 4; }

run_dir="$ROOT/results/$group_dir/$physical_case/$mesh_name/$core_label"
out_dir="$run_dir/output"
mkdir -p "$run_dir"

if [[ -f "$run_dir/RUN_COMPLETE" ]]; then
    echo "SKIP completed: $case_id"
    exit 0
fi

rm -rf "$out_dir"
rm -f "$run_dir/RUN_FAILED" "$run_dir/RUN_COMPLETE"
mkdir -p "$out_dir"

# Identical production physics/numerical controls used by the frozen V95 campaigns.
END_TIME=${END_TIME:-2.0}
WRITE_INTERVAL=${WRITE_INTERVAL:-2.0}
DT0=${DT0:-1e-7}
DTMAX=${DTMAX:-1e-4}
PROGRESS_EVERY=${PROGRESS_EVERY:-1000}
RHO0=${RHO0:-1.0}
MU0=${MU0:-2.0e-5}
CP0=${CP0:-1000.0}
PR0=${PR0:-0.7}
SC0=${SC0:-1.0}
HFF=${HFF:-3.571428571e6}

# RMT_IMPROVED_GP6 fixed campaign controls.
RMT_POST=${RMT_POST:-6}
RMT_MAX_CYCLES=${RMT_MAX_CYCLES:-500}
RMT_LEVELS=${RMT_LEVELS:-8}
RMT_TASK_DEPTH=${RMT_TASK_DEPTH:-2}
RMT_COARSE_ITERS=${RMT_COARSE_ITERS:-64}
RMT_COARSE_REL_TOL=${RMT_COARSE_REL_TOL:-1e-11}
RMT_OMEGA_START=${RMT_OMEGA_START:-1.0}
RMT_BACKTRACKS=${RMT_BACKTRACKS:-10}
P_REL_TOL=${P_REL_TOL:-1e-4}
P_ABS_TOL=${P_ABS_TOL:-1e-6}

cat > "$run_dir/parameters.txt" <<PARAMS
array_index=$array_index
case_id=$case_id
study_family=$study_family
group_dir=$group_dir
physical_case=$physical_case
mesh_name=$mesh_name
Nx=$Nx
Ny=$Ny
cells=$((Nx*Ny))
velocity_m_per_s=$velocity
stiffness_class=$stiffness_class
A=$A
beta=$beta
Ta_K=$Ta
threads=$threads
core_label=$core_label
solver=RMT_IMPROVED_GP6
rmt_post_sweeps=$RMT_POST
rmt_max_cycles=$RMT_MAX_CYCLES
rmt_max_levels=$RMT_LEVELS
rmt_task_depth=$RMT_TASK_DEPTH
rmt_coarse_max_iters=$RMT_COARSE_ITERS
rmt_coarse_rel_tol=$RMT_COARSE_REL_TOL
rmt_omega_start=$RMT_OMEGA_START
rmt_max_backtracks=$RMT_BACKTRACKS
pressure_rel_tol=$P_REL_TOL
pressure_abs_tol=$P_ABS_TOL
end_time=$END_TIME
write_interval=$WRITE_INTERVAL
dt0=$DT0
dtMax=$DTMAX
rho=$RHO0
mu=$MU0
cp=$CP0
Pr=$PR0
Sc=$SC0
HfF=$HFF
variableCp=0
variableDensity=0
sutherland=0
job_id=${SLURM_JOB_ID:-manual}
array_job_id=${SLURM_ARRAY_JOB_ID:-manual}
array_task_id=${SLURM_ARRAY_TASK_ID:-manual}
node=$(hostname)
start=$(date --iso-8601=seconds)
PARAMS

export OMP_NUM_THREADS="$threads"
export OMP_DYNAMIC=false
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_WAIT_POLICY=active

start_ns=$(date +%s%N)
set +e
srun --nodes=1 --ntasks=1 --cpus-per-task="$threads" --exclusive --cpu-bind=cores \
    "$EXE" \
    -Nx "$Nx" -Ny "$Ny" \
    -end "$END_TIME" -dt "$DT0" -dtMax "$DTMAX" \
    -vFuel "$velocity" -vOx "-$velocity" \
    -threads "$threads" -caseId "$case_id" \
    -pCycles "$RMT_MAX_CYCLES" -pRelTol "$P_REL_TOL" -pAbsTol "$P_ABS_TOL" \
    -rmtPost "$RMT_POST" -rmtLevels "$RMT_LEVELS" \
    -rmtTaskDepth "$RMT_TASK_DEPTH" \
    -rmtCoarseIters "$RMT_COARSE_ITERS" -rmtCoarseRelTol "$RMT_COARSE_REL_TOL" \
    -rmtOmegaStart "$RMT_OMEGA_START" -rmtBacktracks "$RMT_BACKTRACKS" \
    -writeOutput 1 -write "$WRITE_INTERVAL" -outputDir "$out_dir" \
    -progressEvery "$PROGRESS_EVERY" \
    -A "$A" -beta "$beta" -Ta "$Ta" \
    -perfectGas 0 -variableCp 0 -sutherland 0 -rhoRelax 1 \
    -rho "$RHO0" -mu "$MU0" -cp "$CP0" -Pr "$PR0" -Sc "$SC0" -HfF "$HFF" \
    > "$run_dir/run.log" 2>&1
rc=$?
set -e

end_ns=$(date +%s%N)
launcher_wall=$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN {printf "%.9f", (e-s)/1.0e9}')

cat > "$run_dir/launcher_timing.txt" <<TIMING
launcher_wall_seconds_including_srun_and_output=$launcher_wall
exit_code=$rc
finish=$(date --iso-8601=seconds)
TIMING

valid=1
[[ $rc -eq 0 ]] || valid=0
[[ -s "$out_dir/summary.csv" ]] || valid=0
[[ -s "$out_dir/fields.pvd" ]] || valid=0
[[ -s "$out_dir/performance/pressure_step_history.csv" ]] || valid=0
[[ -s "$out_dir/performance/final_pressure_cycle_history.csv" ]] || valid=0
grep -q '^Done\.' "$run_dir/run.log" || valid=0
grep -q ',RMT_IMPROVED_GP6,' "$out_dir/summary.csv" || valid=0

if [[ $valid -eq 1 ]]; then
    touch "$run_dir/RUN_COMPLETE"
    echo "COMPLETED: $case_id launcher_wall=${launcher_wall}s"
else
    cat > "$run_dir/RUN_FAILED" <<FAIL
case_id=$case_id
exit_code=$rc
finish=$(date --iso-8601=seconds)
FAIL
    echo "FAILED: $case_id exit=$rc" >&2
    exit ${rc:-1}
fi
