#!/bin/bash
set -euo pipefail
ROOT=${ROOT:-$PWD}
MANIFEST="$ROOT/campaign_manifest.csv"
while IFS=',' read -r array_index case_id study_family group_dir physical_case mesh_name Nx Ny velocity stiffness_class A beta Ta threads core_label; do
    [[ "$array_index" == "array_index" ]] && continue
    run_dir="$ROOT/results/$group_dir/$physical_case/$mesh_name/$core_label"
    if [[ ! -f "$run_dir/RUN_COMPLETE" ]]; then
        echo "$array_index $case_id"
    fi
done < "$MANIFEST"
