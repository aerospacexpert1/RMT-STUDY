#!/usr/bin/env python3
"""
Create a fixed-six-postsmoothing experimental variant from the validated
RMT_FINALVOL2 96-case production package.

The patch deliberately preserves the optimized single-workspace RMT hierarchy,
cached/direct terminal treatment, physics, manifest, stopping criteria and all
other production infrastructure.  It changes the fixed RMT smoothing budget
from 16 to 6 and gives the solver/campaign a separate identity.

This is intentionally a conservative overnight experiment: it changes the
largest measured per-cycle work term without replacing the already-optimized
RMT data structures by a new unvalidated implementation.
"""
from __future__ import annotations
import re
import shutil
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_improved_s6.py PATH_TO_EXTRACTED_COPY")

root = Path(sys.argv[1]).resolve()
if not root.is_dir():
    raise SystemExit(f"not a directory: {root}")

backup = root / "S6_PATCH_BACKUP"
backup.mkdir(exist_ok=True)

TEXT_NAMES = {
    "Makefile",
    "run_case.sh",
    "build.sh",
    "build_rmt.slurm",
    "rmt_96_array.slurm",
    "submit_gated_96.sh",
    "collect_summary.py",
    "smoke_local.sh",
}
TEXT_SUFFIXES = {".c", ".h", ".py", ".sh", ".slurm", ".md", ".txt"}

changes = []
smooth_changes = 0
label_changes = 0
path_changes = 0

def is_patchable(p: Path) -> bool:
    rel = p.relative_to(root)
    if rel.parts and rel.parts[0] in {"tests", "S6_PATCH_BACKUP", "results", "build"}:
        return False
    return p.name in TEXT_NAMES or p.suffix.lower() in TEXT_SUFFIXES

def patch_line(line: str, rel: str) -> str:
    global smooth_changes, label_changes, path_changes
    original = line

    # Separate identity: do not mix new summaries with the thesis baseline.
    n = line.count("RMT_FINALVOL2")
    if n:
        line = line.replace("RMT_FINALVOL2", "RMT_IMPROVED_S6")
        label_changes += n

    # If scripts contain a literal package-root name, point them at the copy.
    n = line.count("RMT_TRUBA_96CASE")
    if n:
        line = line.replace("RMT_TRUBA_96CASE", "RMT_IMPROVED_S6_TRUBA_96CASE")
        path_changes += n

    # Fixed smoothing experiment.  Restrict numeric edits to lines whose
    # semantics explicitly mention smoothing/sweeps and RMT/finalvol context.
    low = line.lower()
    semantic = (
        ("smooth" in low or "sweep" in low)
        and ("rmt" in low or "finalvol" in low or "post" in low)
    )
    if semantic and re.search(r"(?<![\w.])16(?![\w.])", line):
        line, nsub = re.subn(r"(?<![\w.])16(?![\w.])", "6", line)
        smooth_changes += nsub

    if line != original:
        changes.append((rel, original.rstrip("\n"), line.rstrip("\n")))
    return line

for p in sorted(root.rglob("*")):
    if not p.is_file() or not is_patchable(p):
        continue
    try:
        text = p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    rel = str(p.relative_to(root))
    new = "".join(patch_line(line, rel) for line in text.splitlines(keepends=True))
    if new != text:
        b = backup / rel
        b.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, b)
        p.write_text(new, encoding="utf-8")

if smooth_changes < 1:
    raise SystemExit(
        "ABORT: no active RMT smoothing=16 setting was found. "
        "The package layout differs from the validated archive; do not run."
    )
if label_changes < 1:
    raise SystemExit(
        "ABORT: RMT_FINALVOL2 identity was not found. "
        "Refusing to produce an ambiguously labelled campaign."
    )

# Strong audit of active production/generator files.  Documentation may still
# describe 16-sweep historical data, but executable/generator defaults may not.
audit_roots = [
    root / "src",
    root / "tools",
    root / "calibration",
    root / "run_case.sh",
    root / "build.sh",
]
remaining = []
for item in audit_roots:
    paths = [item] if item.is_file() else (list(item.rglob("*")) if item.exists() else [])
    for p in paths:
        if not p.is_file() or "tests" in p.parts or "S6_PATCH_BACKUP" in p.parts:
            continue
        try:
            lines = p.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for no, line in enumerate(lines, 1):
            low = line.lower()
            semantic = (
                ("smooth" in low or "sweep" in low)
                and ("rmt" in low or "finalvol" in low or "post" in low)
            )
            if semantic and re.search(r"(?<![\w.])16(?![\w.])", line):
                remaining.append((str(p.relative_to(root)), no, line.strip()))

report = root / "S6_PATCH_REPORT.txt"
with report.open("w", encoding="utf-8") as f:
    f.write("RMT_IMPROVED_S6 patch report\n")
    f.write("============================\n")
    f.write(f"smoothing numeric replacements: {smooth_changes}\n")
    f.write(f"solver-label replacements: {label_changes}\n")
    f.write(f"package-path replacements: {path_changes}\n")
    f.write(f"changed lines: {len(changes)}\n\n")
    for rel, before, after in changes:
        f.write(f"[{rel}]\n- {before}\n+ {after}\n\n")
    if remaining:
        f.write("REMAINING ACTIVE 16-SWEEP REFERENCES\n")
        for rel, no, line in remaining:
            f.write(f"{rel}:{no}: {line}\n")

if remaining:
    print(report.read_text(encoding="utf-8"))
    raise SystemExit(
        "ABORT: active code/generator still contains an RMT smoothing/sweep "
        "reference to 16. Review S6_PATCH_REPORT.txt before running."
    )

# Add an unambiguous marker inside the generated package.
(root / "IMPROVED_VARIANT.txt").write_text(
    "solver=RMT_IMPROVED_S6\n"
    "basis=RMT_FINALVOL2 validated production package\n"
    "change=fixed RMT smoothing budget 16 -> 6\n"
    "physics=unchanged frozen V95\n"
    "purpose=separate experimental 96-case campaign\n",
    encoding="utf-8",
)

print("PATCH_PASS")
print(f"smoothing replacements: {smooth_changes}")
print(f"label replacements: {label_changes}")
print(f"report: {report}")
