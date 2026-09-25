#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
ARCHIVE="$REPO_ROOT/RMT_TRUBA_96CASE.rar"
DEST="$REPO_ROOT/RMT_IMPROVED_S6_TRUBA_96CASE"
TMP="$REPO_ROOT/.rmt_s6_extract_tmp"

[[ -f "$ARCHIVE" ]] || {
    echo "ERROR: archive not found: $ARCHIVE" >&2
    exit 2
}

rm -rf "$TMP"
mkdir -p "$TMP"

echo "===== EXTRACT VALIDATED RMT_FINALVOL2 PACKAGE ====="
if command -v 7z >/dev/null 2>&1; then
    7z x -y "$ARCHIVE" -o"$TMP" >/dev/null
elif command -v 7zz >/dev/null 2>&1; then
    7zz x -y "$ARCHIVE" -o"$TMP" >/dev/null
elif command -v unrar >/dev/null 2>&1; then
    unrar x -o+ "$ARCHIVE" "$TMP/" >/dev/null
else
    echo "ERROR: no RAR extractor found (7z, 7zz, or unrar)." >&2
    echo "Check available TRUBA modules with: module avail 2>&1 | grep -Ei '7zip|7z|rar'" >&2
    exit 3
fi

SRC="$TMP/RMT_TRUBA_96CASE"
[[ -d "$SRC" ]] || {
    echo "ERROR: expected extracted directory not found: $SRC" >&2
    find "$TMP" -maxdepth 2 -type d -print
    exit 4
}

rm -rf "$DEST"
cp -a "$SRC" "$DEST"

echo "===== APPLY FIXED-S6 PATCH ====="
python3 "$HERE/patch_improved_s6.py" "$DEST"

cat > "$DEST/verify_improved_s6.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "===== VARIANT ====="
cat IMPROVED_VARIANT.txt

echo "===== PATCH REPORT SUMMARY ====="
head -20 S6_PATCH_REPORT.txt

echo "===== ACTIVE RMT SMOOTHING REFERENCES ====="
grep -RniE 'rmt.*(smooth|sweep)|(smooth|sweep).*rmt|finalvol.*(smooth|sweep)'     src tools calibration run_case.sh build.sh 2>/dev/null | head -100 || true

echo "===== BASELINE IDENTITY CHECK ====="
if grep -Rni 'RMT_FINALVOL2' src tools calibration run_case.sh build.sh 2>/dev/null; then
    echo "ERROR: baseline solver identity remains in active production files." >&2
    exit 20
fi

echo "VERIFY_S6_PATCH_PASS"
EOF

cat > "$DEST/preflight_s6.slurm" <<'EOF'
#!/bin/bash
#SBATCH --job-name=RMT_S6_PRE
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=00:30:00
#SBATCH --output=preflight_s6-%j.out
#SBATCH --error=preflight_s6-%j.err

set -euo pipefail
module purge
module load comp/gcc/12.3.0
cd "$SLURM_SUBMIT_DIR"

chmod +x build.sh smoke_local.sh verify_improved_s6.sh 2>/dev/null || true

./verify_improved_s6.sh
./build.sh

echo "===== POST-BUILD SOURCE AUDIT ====="
./verify_improved_s6.sh

echo "===== EXISTING PACKAGE SMOKE TEST ====="
./smoke_local.sh

echo "RMT_IMPROVED_S6_PREFLIGHT_PASS"
EOF

cat > "$DEST/postprocess_s6.slurm" <<'EOF'
#!/bin/bash
#SBATCH --job-name=RMT_S6_SUM
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00
#SBATCH --output=postprocess_s6-%j.out
#SBATCH --error=postprocess_s6-%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
python3 collect_summary.py
wc -l campaign_summary.csv
EOF

cat > "$DEST/submit_s6_96.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p logs 2>/dev/null || true

if squeue -h -u "$USER" -o "%j" | grep -Eq '^(RMT_S6_PRE|RMT_S6_96)$'; then
    echo "ERROR: an RMT_IMPROVED_S6 job is already active." >&2
    squeue -u "$USER"
    exit 1
fi

PRE=$(sbatch --parsable preflight_s6.slurm)

# Use the validated production array script after the preflight.
PRIMARY=$(sbatch --parsable --dependency=afterok:$PRE rmt_96_array.slurm)

# Only schedule an automatic rescue when the validated runner has a completed
# marker/skip mechanism. Otherwise avoid silently recomputing all 96 cases.
RESCUE=""
if grep -q 'RUN_COMPLETE' run_case.sh && grep -qi 'skip' run_case.sh; then
    RESCUE=$(sbatch --parsable --dependency=afterany:$PRIMARY rmt_96_array.slurm)
    POST_DEP="$RESCUE"
else
    POST_DEP="$PRIMARY"
fi

POST=$(sbatch --parsable --dependency=afterany:$POST_DEP postprocess_s6.slurm)

cat > RMT_IMPROVED_S6_JOBIDS.txt <<JOBS
PREFLIGHT=$PRE
PRIMARY=$PRIMARY
RESCUE=$RESCUE
POSTPROCESS=$POST
SUBMITTED=$(date --iso-8601=seconds)
JOBS

echo "RMT_IMPROVED_S6 submitted"
echo "preflight=$PRE"
echo "primary=$PRIMARY"
echo "rescue=$RESCUE"
echo "postprocess=$POST"
echo
squeue -u "$USER"
EOF

chmod +x "$DEST"/*.sh "$DEST"/*.slurm 2>/dev/null || true

cat >> "$DEST/README.md" <<'EOF'

---

## Experimental RMT_IMPROVED_S6 variant

This directory was generated from the validated RMT_FINALVOL2 96-case package.
The frozen V95 physics and production RMT data structures are retained.

The experimental change is a fixed reduction of the RMT smoothing budget from
16 to 6 sweeps.  The solver identity is changed to RMT_IMPROVED_S6 so the new
results cannot be confused with the thesis baseline.

Launch through:

    ./submit_s6_96.sh

The full 96-case array starts only if the debug-partition source audit, build,
and the package's existing smoke test all succeed.
EOF

echo
echo "============================================================"
echo " CREATED: $DEST"
echo "============================================================"
echo "Next:"
echo "  cd $DEST"
echo "  ./verify_improved_s6.sh"
echo "  ./submit_s6_96.sh"
echo
