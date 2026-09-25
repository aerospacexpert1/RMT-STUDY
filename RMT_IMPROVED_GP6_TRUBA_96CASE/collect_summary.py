#!/usr/bin/env python3
import csv
from pathlib import Path

root=Path(__file__).resolve().parent
manifest=list(csv.DictReader((root/"campaign_manifest.csv").open()))
rows=[]

for m in manifest:
    run_dir=root/"results"/m["group_dir"]/m["physical_case"]/m["mesh_name"]/m["core_label"]
    summary=run_dir/"output"/"summary.csv"
    timing=run_dir/"launcher_timing.txt"

    row=dict(m)
    row["status"]="complete" if (run_dir/"RUN_COMPLETE").exists() else "incomplete"
    row["run_dir"]=str(run_dir.relative_to(root))
    row["launcher_wall_seconds"]=""
    row["exit_code"]=""

    if timing.exists():
        for line in timing.read_text(errors="replace").splitlines():
            if "=" in line:
                k,v=line.split("=",1)
                if k=="launcher_wall_seconds_including_srun_and_output":
                    row["launcher_wall_seconds"]=v
                elif k=="exit_code":
                    row["exit_code"]=v

    if summary.exists() and summary.stat().st_size:
        try:
            s=next(csv.DictReader(summary.open()))
            for k,v in s.items():
                key=k if k not in row else "summary_"+k
                row[key]=v
        except Exception as e:
            row["summary_error"]=str(e)

    rows.append(row)

keys=[]
for r in rows:
    for k in r:
        if k not in keys:
            keys.append(k)

out=root/"campaign_summary.csv"
with out.open("w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=keys)
    w.writeheader()
    w.writerows(rows)

complete=sum(r["status"]=="complete" for r in rows)
print(f"Wrote {out} with {len(rows)} rows")
print(f"Complete: {complete}/{len(rows)}")
print(f"Incomplete: {len(rows)-complete}")
