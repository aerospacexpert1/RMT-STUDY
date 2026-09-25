#!/bin/bash
#SBATCH --job-name=RMTI_SUMMARY
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=logs/postprocess-%j.out
#SBATCH --error=logs/postprocess-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

python3 collect_summary.py
./check_campaign_status.sh

echo "===== UNFINISHED ====="
./list_unfinished.sh || true

echo "===== SUMMARY LINES ====="
wc -l campaign_summary.csv
