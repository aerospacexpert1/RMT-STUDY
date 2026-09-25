#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p logs

if squeue -h -u "$USER" -o "%j" | grep -Eq '^(RMTI_PREFLIGHT|RMTI_GP6_96)$'; then
    echo "ERROR: an improved-RMT campaign/preflight is already active."
    squeue -u "$USER"
    exit 1
fi

PRE=$(sbatch --parsable preflight_rmt_improved.slurm)
FULL=$(sbatch --parsable --dependency=afterok:$PRE rmt_improved_96_array.slurm)
RESCUE=$(sbatch --parsable --dependency=afterany:$FULL rmt_improved_96_array.slurm)
POST=$(sbatch --parsable --dependency=afterany:$RESCUE postprocess_summary.slurm)

cat > RMT_IMPROVED_JOBIDS.txt <<EOF
PREFLIGHT=$PRE
PRIMARY=$FULL
RESCUE=$RESCUE
POSTPROCESS=$POST
SUBMITTED=$(date --iso-8601=seconds)
EOF

echo "RMT_IMPROVED_GP6 submitted"
echo "preflight=$PRE"
echo "primary=$FULL"
echo "rescue=$RESCUE"
echo "postprocess=$POST"
echo
echo "The primary 96-case array starts only if preflight succeeds."
echo "The rescue array starts after the primary and automatically skips RUN_COMPLETE cases."
echo "The postprocess job writes campaign_summary.csv after the rescue pass."
echo
squeue -u "$USER"
