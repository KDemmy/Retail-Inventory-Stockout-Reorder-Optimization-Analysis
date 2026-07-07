# 📦 Retail Inventory Stockout Diagnosis & Reorder Optimization

A SQL-driven analytics project diagnosing the root cause of retail stockouts and testing whether a demand-responsive reorder policy can profitably reduce them — built on 73,100 real inventory transaction records.

---

## 🔍 Project Overview

Most inventory dashboards stop at reporting a stockout rate. This project asks the harder question: **is a low stockout rate actually good, and if we fix the remaining stockouts, is it even worth it?**

**Key result:** A 0.50% stockout rate looked like strong inventory management — until the data showed it was actually driven by carrying ~2x more inventory than needed, uniformly, across every category. The real fix required identifying *where* ordering was too rigid to respond to demand, then testing whether correcting that was economically worth it.

---

## 🗂️ Dataset

| Field | Description |
|---|---|
| Date, Store_ID, Product_ID | Transaction identifiers |
| Category, Region | Electronics / Toys / Groceries / Furniture / Clothing; North / South / East / West |
| Inventory_Level, Units_Sold, Units_Ordered | Core stock movement fields |
| Demand_Forecast | System-generated forecast (contained data-quality issues — see below) |
| Price, Discount, Competitor_Pricing | Pricing fields |
| Holiday_Promotion, Weather_Condition, Seasonality | Contextual fields |

- **73,100 rows** across **25 months** (2022–2024)
- 5 categories × 4 regions

---

## 🛠️ Tech Stack

- **MySQL** — data cleaning, feature engineering, statistical aggregation, simulation
- **SQL functions used:** `STDDEV`, `GREATEST`/`LEAST`, `CASE WHEN`, window-free grouped aggregation, iterative `UPDATE` pipelines
- *(Planned extension: Python/Pandas Monte Carlo demand simulation — not yet implemented, see Limitations)*

---

## 📊 Methodology

### 1. Data Cleaning
Found **673 rows (0.92%)** with negative `Demand_Forecast` values, tightly clustered between -6.5 and -10 with no concentration by category/region/month — consistent with noise around near-zero predictions rather than a pipeline failure.

```sql
ALTER TABLE retail_store_inventory ADD COLUMN Demand_Forecast_N DECIMAL(10,2);

UPDATE retail_store_inventory
SET Demand_Forecast_N = GREATEST(Demand_Forecast, 0);
```

### 2. Stockout Feature Engineering
```sql
ALTER TABLE retail_store_inventory
ADD COLUMN closing_stock INT,
ADD COLUMN stockout_flag TINYINT;

UPDATE retail_store_inventory
SET closing_stock = Inventory_Level - Units_Sold;

UPDATE retail_store_inventory
SET stockout_flag = CASE WHEN closing_stock <= 0 THEN 1 ELSE 0 END;
```

### 3. Root Cause Diagnosis
Grouped analysis across Category, Promotion, Region, and a Coefficient-of-Variation comparison between demand and orders:

```sql
SELECT
    Category,
    ROUND(AVG(Units_Sold), 1) AS avg_units_sold,
    ROUND(AVG(Demand_Forecast_N), 1) AS avg_demand_forecast,
    ROUND(AVG(Price), 2) AS avg_price,
    ROUND(100 * SUM(stockout_flag) / COUNT(*), 2) AS stockout_pct
FROM retail_store_inventory
GROUP BY Category
ORDER BY stockout_pct DESC;
```

**Finding:** `Units_Ordered` stayed nearly flat (~108–111 units) across every category and promotion status, while `Demand_Forecast` and `Units_Sold` fluctuated substantially (CV ~77–82% vs ~46–49% for orders). **The ordering process — not the forecast — was the root cause.**

### 4. Cost-Based Reorder Model
Standard safety-stock formula, with Z derived from a cost trade-off (critical ratio / newsvendor model) rather than an arbitrary service level:

```
Reorder_Qty = Demand_Forecast_N + (Z × STDDEV(Units_Sold))
Critical_Ratio = Cost_of_Stockout / (Cost_of_Stockout + Cost_of_Overstock)
```
- Assumed margin: 25% of Price → Cost of Stockout
- Assumed holding cost: 20% of Price → Cost of Overstock
- Critical Ratio = 55.6% → **Z = 0.14**

```sql
UPDATE retail_store_inventory
SET New_Reorder_Qty = GREATEST(
    Demand_Forecast_N + 0.14 * (
        CASE Category
            WHEN 'Groceries'   THEN 109.25
            WHEN 'Toys'        THEN 108.43
            WHEN 'Electronics' THEN 108.44
            WHEN 'Furniture'   THEN 110.01
            WHEN 'Clothing'    THEN 108.42
        END
    ), Units_Ordered
);
```

### 5. Simulation & Iterative Refinement
Tested the model at three levels of targeting precision to see whether the fix was actually cost-justified — not just effective:

| Version | Scope | Stockout Reduction | Net Monthly Impact |
|---|---|---|---|
| Blanket | All rows | 369 → 103 (**−72.1%**) | −₹5,873 |
| Targeted | 6 highest-risk category×region combos | Reduced | −₹1,697 |
| Threshold-Conditional | High-risk combos, high-forecast days only | Reduced | −₹990 |

---

## 📈 Key Findings

1. **Low stockout rate ≠ good inventory management** — average `closing_stock` (~137–139 units) nearly equals average `Units_Sold` in every category, meaning ~2x more inventory is held than sold, uniformly.
2. **Forecasting is accurate; ordering is rigid** — forecast tracks actual sales closely even on stockout rows; `Units_Ordered` barely moves regardless of demand level.
3. **Stockouts concentrate in specific segments** — Toys, Furniture, Electronics, and the West region carry disproportionate risk (up to 0.72% vs the 0.50% overall average).
4. **A 72% stockout reduction is achievable — but not automatically worth it.** Iteratively refining the intervention's targeting cut its net cost by **~83%** (−₹5,873 → −₹990/month), but even the most precise version tested remained cost-negative under current margin assumptions.
5. **The mature conclusion:** the value of a fix should scale with how often the underlying problem occurs — with stockouts affecting <1% of transactions, a blanket inventory increase is not the right lever; targeted, forecast-triggered ordering rules are.

---

## ⚠️ Assumptions & Limitations

- Margin (25%) and holding cost (20%) are industry-typical assumptions, not measured company data.
- Safety stock formula assumes a 1-period lead time (no supplier lead-time field available).
- `Units_Sold` is capped by available inventory in the raw data; true unmet demand on stockout rows was estimated via `Demand_Forecast_N`, not directly observed.
- STDDEV calculated at category level (pooled across stores/regions) — a per-store/per-SKU volatility measure could sharpen the model further.
- Python/Monte Carlo demand-distribution simulation identified as the natural next enhancement, not yet built.

---

## 🚀 Next Steps

- [ ] Monte Carlo simulation (Python/NumPy) to model demand as a distribution rather than a point forecast
- [ ] Category-specific margin/holding-cost assumptions (vs. current uniform rate)
- [ ] Power BI dashboard: stockout %, order-vs-demand CV comparison, region heatmap
- [ ] Validate assumptions against real supplier lead-time and margin data if applied to an actual business

---

## 🧠 What This Project Demonstrates

- End-to-end SQL analytics: cleaning → feature engineering → statistical modeling → simulation → iterative refinement
- Statistical grounding: STDDEV, Coefficient of Variation, cost-based service-level (critical ratio) modeling
- Debugging rigor: caught and corrected three real modeling errors during development (a unit-mismatch in cost comparison, a reorder formula that could recommend under-ordering, and stale dependent columns after re-segmenting logic)
- Business judgment: concluding that an intervention isn't cost-justified is a legitimate, evidence-based outcome — not every diagnosed problem is worth solving with the same fix
