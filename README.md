# 🛒 Project 1: Retail Sales Performance Dashboard

> **End-to-end analytics pipeline** — SQL extraction → Python ETL → Power BI Dashboard

---

## 📁 Project Structure

```
project1_sales_dashboard/
├── README.md                    ← You are here
├── sql/
│   ├── 01_data_exploration.sql  ← Initial data profiling queries
│   ├── 02_sales_aggregations.sql← Core business metrics
│   ├── 03_cohort_analysis.sql   ← Customer cohort queries
│   └── 04_regional_benchmark.sql← Regional comparison queries
├── notebooks/
│   ├── 01_eda.ipynb             ← Exploratory Data Analysis
│   ├── 02_etl_pipeline.ipynb    ← Data cleaning & transformation
│   └── 03_insights_summary.ipynb← Key findings & visualizations
├── data/
│   ├── generate_data.py         ← Script to generate synthetic dataset
│   └── README_data.md           ← Data dictionary
└── reports/
    └── executive_summary.md     ← Non-technical findings summary
```

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/yourname/data-analyst-portfolio.git
cd project1_sales_dashboard

# 2. Install dependencies
pip install -r requirements.txt

# 3. Generate synthetic data
python data/generate_data.py

# 4. Open notebooks in order
jupyter lab notebooks/
```

---

## 📊 Dashboard Preview

The Power BI dashboard includes 8 pages:
1. **Executive Summary** — KPI scorecards, MoM/YoY trends
2. **Regional Performance** — Map view + benchmarking table
3. **Product Category Deep Dive** — Margin analysis, velocity
4. **Store-Level Analysis** — Sortable ranking with drill-through
5. **Customer Segmentation** — RFM quadrant chart
6. **Seasonal Patterns** — Heatmap calendar + YoY overlay
7. **Return Rate Analysis** — Category/SKU-level returns
8. **Forecast** — 90-day rolling forecast with confidence bands

---

## 🔍 Methodology

### 1. Data Extraction (SQL)
Connected to PostgreSQL instance containing:
- `transactions` table: 2.4M rows, 3 years of daily sales
- `products` table: 847 SKUs across 12 categories
- `stores` table: 47 locations with metadata
- `customers` table: 89,000 unique customer profiles

### 2. Data Cleaning (Python/Pandas)
Key issues addressed:
- 3.2% missing values in `product_id` → joined on SKU from product master
- Duplicate transactions from POS system reboot events (identified via timestamp dedup)
- Currency normalization across 2 store acquisitions with different pricing schemas
- Outlier capping for fraudulent returns (>3 SD from category mean)

### 3. Feature Engineering
Created derived metrics:
- `revenue_per_sqft` — store efficiency metric
- `basket_size` — avg items per transaction
- `customer_lifetime_days` — days from first to last purchase
- `stockout_rate` — % of days item had zero sales (proxy for stockout)

### 4. Analysis
- Pareto analysis (top customers by revenue)
- YoY/MoM trending with seasonality decomposition
- Regional cohort comparison (same-store sales)
- Category margin waterfall analysis
