# Insurance Claims Intelligence — Life Claims Track

**Do headline claim settlement numbers actually reflect what policyholders get paid?**
This project builds a custom **Claims Reliability Index (CRI)** to answer that using five years of IRDAI life-insurance data — going beyond the standard Claim Settlement Ratio (CSR).

---

## Why this project

Indian life insurers report a **Claim Settlement Ratio (CSR)** — the % of claims settled — as their headline reliability metric. But CSR is usually reported *by count* of claims, not *by value* paid out. A company can settle 98% of claims by count while settling far less of the actual rupee value, if the unsettled claims are the high-value ones.

This project tests that gap directly, and builds a fairer, multi-dimensional reliability score.

## Key findings

- **Count vs. value gap is real and persistent.** Median Count-based CSR was **98.5%**, while median Value-based CSR was **95.3%** — a ~3 pp gap industry-wide.
- **Shriram Life is a consistent outlier**: its Count–Value CSR gap stayed **above 10 percentage points in all 5 years** studied (median gap: 17.6 pp).
- Two insurers (**Acko Life, Credit Access Life**) had no usable claims data across the study window and were excluded from the CRI rather than force-fit — documented in the data audit rather than silently dropped.
- A custom **Claims Reliability Index (CRI)**, combining 7 metrics (settlement, repudiation, pending-claim ageing, unclaimed amounts), was built and **stress-tested with sensitivity analysis** to check how much insurer rankings move when metric weights change.

## Data

- **Source:** IRDAI Annual Handbook on Indian Insurance Statistics
- **Period:** FY 2020-21 to FY 2024-25 (5 years)
- **Coverage:** 27 life insurers → **122 insurer-year records** after cleaning
- **Challenge:** table layouts and column naming shifted across the five yearly handbooks, requiring manual extraction and standardization rather than a single automated parser

## Methodology / Pipeline

```
Extract (IRDAI handbooks, 5 years)
   → Data Audit (completeness, consistency checks across years)
   → Cleaning (standardize layouts, handle missing/low-volume records)
   → Feature Engineering (7 reliability metrics)
   → EDA (count vs. value gap, repudiation patterns)
   → Claims Reliability Index (weighted score + sensitivity analysis)
   → SQL analysis layer (year-wise ranking, CRI movement)
   → Power BI dashboard (insurer reliability across financial years)
```

Notebooks are numbered in pipeline order (`01_Life_Data_Audit` → `05_Life_CRI`) so each stage's input/output is traceable to the next.

## Reliability metrics behind the CRI

| Metric | What it captures |
|---|---|
| Count-based CSR | % of claims settled, by number |
| Value-based CSR | % of claim value settled, by rupees |
| Count–Value Gap | Divergence between the two above |
| Repudiation Rate | Share of claims rejected |
| Pending Claims Ageing | How long unsettled claims stay open |
| Unclaimed Amount | Value never claimed by beneficiaries |
| Low-volume flag | Marks insurer-years with too few claims to rank reliably, instead of dropping them |

## Honest limitations

- CRI weights across the 7 metrics are a design choice, not derived from an external ground truth — this is why sensitivity analysis is included, to show how rankings shift under different weightings rather than presenting one fixed ranking as definitive.
- Overall correlation between Count–Value gap and repudiation rate was weak industry-wide; the repudiation effect only showed up when comparing the top and bottom quartiles by gap size — so it's reported as an association within that subgroup, not a general driver.
- IRDAI handbook data is aggregated at the insurer level, not policy level, so the CRI describes insurer-level patterns, not individual claim outcomes.

## Tech stack

`Python (Pandas, NumPy)` · `MySQL` · `Power BI` · Statistical validation

## SQL & Dashboard

*(In progress)* A MySQL analysis layer (CTEs, window functions) for year-wise insurer ranking and CRI movement, and a Power BI dashboard tracking insurer reliability across financial years, are being added — `sql/` and `dashboard/` folders will be updated once complete.

## Repo structure

```
├── 01_Life_Data_Audit.ipynb
├── 02_Life_Data_Cleaning.ipynb
├── 03_Life_Feature_Engineering.ipynb
├── 04_Life_EDA.ipynb
├── 05_Life_CRI.ipynb
├── sql/                  # (coming soon)
├── dashboard/            # (coming soon)
└── README.md
```
