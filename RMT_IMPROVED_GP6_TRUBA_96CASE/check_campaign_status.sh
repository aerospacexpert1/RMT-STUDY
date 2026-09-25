#!/bin/bash
set -euo pipefail
ROOT=${ROOT:-$PWD}
total=$(($(wc -l < "$ROOT/campaign_manifest.csv")-1))
complete=$(find "$ROOT/results" -type f -name RUN_COMPLETE 2>/dev/null | wc -l || true)
failed=$(find "$ROOT/results" -type f -name RUN_FAILED 2>/dev/null | wc -l || true)
echo "completed=$complete / $total"
echo "failed_markers=$failed"
