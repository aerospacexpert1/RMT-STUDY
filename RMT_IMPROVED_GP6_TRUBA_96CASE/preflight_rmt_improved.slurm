#!/bin/bash
#SBATCH --job-name=RMTI_PREFLIGHT
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=00:30:00
#SBATCH --output=logs/preflight-%j.out
#SBATCH --error=logs/preflight-%j.err

set -euo pipefail
module purge
module load comp/gcc/12.3.0
cd "$SLURM_SUBMIT_DIR"
mkdir -p logs smoke

echo "===== BUILD ====="
./build.sh

echo "===== SHORT 16-THREAD SMOKE ====="
rm -rf smoke/output
mkdir -p smoke/output

export OMP_NUM_THREADS=16
export OMP_DYNAMIC=false
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_WAIT_POLICY=active

srun --nodes=1 --ntasks=1 --cpus-per-task=16 --exclusive --cpu-bind=cores \
    ./build/opposedflow_rmt_improved \
    -Nx 108 -Ny 36 -end 0.002 -dt 1e-7 -dtMax 1e-4 \
    -vFuel 0.10 -vOx -0.10 -threads 16 -caseId PREFLIGHT_S2_M1_C16 \
    -pCycles 500 -pRelTol 1e-4 -pAbsTol 1e-6 \
    -rmtPost 6 -rmtLevels 8 -rmtTaskDepth 2 \
    -rmtCoarseIters 64 -rmtCoarseRelTol 1e-11 \
    -rmtOmegaStart 1.0 -rmtBacktracks 10 \
    -writeOutput 1 -write 0.002 -outputDir smoke/output \
    -progressEvery 100 \
    -A 1e8 -beta 5 -Ta 500 \
    -perfectGas 0 -variableCp 0 -sutherland 0 -rhoRelax 1 \
    -rho 1.0 -mu 2e-5 -cp 1000 -Pr 0.7 -Sc 1.0 -HfF 3.571428571e6 \
    > smoke/preflight.log 2>&1

grep -q '^Done\.' smoke/preflight.log
grep -q ',RMT_IMPROVED_GP6,' smoke/output/summary.csv

python3 - <<'PY'
import csv, math
r=next(csv.DictReader(open("smoke/output/summary.csv")))
assert r["solver"]=="RMT_IMPROVED_GP6"
assert float(r["final_pressure_rel_residual"]) <= 1.0e-4 or float(r["final_pressure_abs_residual"]) <= 1.0e-6
for k in ("compute_time_s","pressure_time_s","total_wall_s","mean_pressure_convergence_factor"):
    assert math.isfinite(float(r[k]))
print("PREFLIGHT_PASS")
print("final_pressure_rel_residual", r["final_pressure_rel_residual"])
print("mean_pressure_convergence_factor", r["mean_pressure_convergence_factor"])
print("diag_backtracks", r["diag_backtracks"])
print("diag_fallback_rbgs_sweeps", r["diag_fallback_rbgs_sweeps"])
PY

echo "===== PREFLIGHT COMPLETE ====="
