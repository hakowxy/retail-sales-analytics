"""Aggregates the raw orders into docs/data.json for the GitHub Pages dashboard.

Run from the repo root:  python scripts/build_dashboard_data.py
"""
import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent

df = pd.read_csv(ROOT / "data/superstore_sales.csv")
df["month"] = pd.to_datetime(df["Order Date"], format="%m/%d/%Y").dt.strftime("%Y-%m")

dims = ["month", "Region", "Customer Segment", "Product Category", "Product Sub-Category", "Ship Mode"]
agg = (
    df.groupby(dims)
    .agg(sales=("Sales", "sum"), profit=("Profit", "sum"), lines=("Sales", "size"))
    .reset_index()
)

# Store each dimension as a lookup list plus integer codes to keep the file small.
out = {"dims": {}, "rows": {}}
for col, key in zip(dims, ["month", "region", "segment", "category", "subcategory", "shipmode"]):
    values = sorted(agg[col].unique())
    out["dims"][key] = values
    out["rows"][key] = agg[col].map({v: i for i, v in enumerate(values)}).tolist()
out["rows"]["sales"] = agg["sales"].round(2).tolist()
out["rows"]["profit"] = agg["profit"].round(2).tolist()
out["rows"]["lines"] = agg["lines"].tolist()

(ROOT / "docs/data.json").write_text(json.dumps(out, separators=(",", ":")))
print(f"{len(agg):,} aggregated rows written to docs/data.json")
