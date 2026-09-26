#!/bin/bash
#SBATCH --job-name=RMTIMP_ONE
#SBATCH --partition=orfoz
#SBATCH --exclude=orfoz359
#SBATCH --nodes=1
#SBATCH --ntasks=56
#SBATCH --cpus-per-task=1
#SBATCH --exclusive
#SBATCH --time=1-00:00:00
#SBATCH --output=slurm-RMTIMP_ONE_%j.out
#SBATCH --error=slurm-RMTIMP_ONE_%j.err
set -euo pipefail
module purge
module load comp/gcc/12.3.0
cd "$SLURM_SUBMIT_DIR"
[[ -x build/opposedflow_rmt_improved ]] || { echo "ERROR: build first" >&2; exit 10; }
[[ -f campaign_manifest.csv ]] || ./rebuild_manifest.sh
TASK_ID=${TASK_ID:-3}
echo "Running RMT_IMPROVED single case TASK_ID=$TASK_ID"
./run_case.sh "$TASK_ID"
