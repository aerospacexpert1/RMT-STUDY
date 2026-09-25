#!/bin/bash
#SBATCH --job-name=RMTI_GP6_96
#SBATCH --partition=orfoz
#SBATCH --exclude=orfoz359
#SBATCH --nodes=1
#SBATCH --ntasks=56
#SBATCH --cpus-per-task=1
#SBATCH --exclusive
#SBATCH --time=3-00:00:00
#SBATCH --array=0-95%3
#SBATCH --output=logs/slurm-RMTI_GP6_96_%A_%a.out
#SBATCH --error=logs/slurm-RMTI_GP6_96_%A_%a.err

set -eo pipefail
module purge
module load comp/gcc/12.3.0
cd "$SLURM_SUBMIT_DIR"

mkdir -p logs
[[ -x build/opposedflow_rmt_improved ]] || { echo "ERROR: build/opposedflow_rmt_improved is missing" >&2; exit 10; }
[[ -f campaign_manifest.csv ]] || { echo "ERROR: campaign_manifest.csv is missing" >&2; exit 11; }
[[ -x run_case.sh ]] || { echo "ERROR: run_case.sh is missing or not executable" >&2; exit 12; }

export ROOT="$SLURM_SUBMIT_DIR"

echo "============================================================"
echo "RMT_IMPROVED_GP6 96-CASE CAMPAIGN"
echo "============================================================"
echo "job=${SLURM_ARRAY_JOB_ID:-$SLURM_JOB_ID} task=$SLURM_ARRAY_TASK_ID"
echo "node=$(hostname) date=$(date --iso-8601=seconds)"
echo "One array task = one physical/mesh/thread case."
echo "RMT: factor-3 3x3 shifts; sawtooth; post=6; taskDepth=2."
echo "============================================================"

./run_case.sh "$SLURM_ARRAY_TASK_ID"
