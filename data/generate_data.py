"""
Project 1: Retail Sales Performance Dashboard
File: data/generate_data.py

Generates realistic synthetic retail transaction data for the project.
Run this script to create the CSV files used in the analysis.

Usage:
    python generate_data.py
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random
import os

np.random.seed(42)
random.seed(42)

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

print("Generating synthetic retail data...")

# ─────────────────────────────────────────────
# 1. STORES (47 stores across 5 regions)
# ─────────────────────────────────────────────

REGIONS = {
    "Northeast":  {"stores": 12, "base_revenue_mult": 1.15},
    "Southeast":  {"stores": 10, "base_revenue_mult": 0.95},
    "Midwest":    {"stores": 9,  "base_revenue_mult": 0.72},   # underperformer
    "Southwest":  {"stores": 8,  "base_revenue_mult": 1.05},
    "West":       {"stores": 8,  "base_revenue_mult": 1.25},
}

stores = []
store_id = 1
for region, cfg in REGIONS.items():
    for i in range(cfg["stores"]):
        stores.append({
            "store_id":         store_id,
            "store_name":       f"{region} Store #{i+1:02d}",
            "region":           region,
            "sqft":             random.choice([5000, 7500, 10000, 12500, 15000]),
            "opened_year":      random.choice([2015, 2016, 2017, 2018, 2019]),
            "revenue_mult":     cfg["base_revenue_mult"] * np.random.uniform(0.85, 1.15),
        })
        store_id += 1

stores_df = pd.DataFrame(stores)
stores_df.to_csv(f"{OUTPUT_DIR}/stores.csv", index=False)
print(f"  ✓ Stores: {len(stores_df)} rows")


# ─────────────────────────────────────────────
# 2. PRODUCTS (847 SKUs across 12 categories)
# ─────────────────────────────────────────────

CATEGORIES = [
    ("Electronics",   0.22,  False),
    ("Clothing",      0.55,  False),
    ("Home & Garden", 0.42,  False),
    ("Food & Bev",    0.28,  True),   # private label dominant
    ("Sports",        0.38,  False),
    ("Beauty",        0.61,  False),
    ("Toys",          0.45,  False),
    ("Books",         0.30,  False),
    ("Automotive",    0.32,  False),
    ("Health",        0.48,  True),
    ("Pet Supplies",  0.40,  True),
    ("Office",        0.35,  False),
]

products = []
pid = 1
for cat, margin_base, pl_dominant in CATEGORIES:
    n_skus = random.randint(50, 90)
    for i in range(n_skus):
        is_private = (pl_dominant and random.random() < 0.4) or (random.random() < 0.12)
        margin = margin_base + (0.15 if is_private else 0) + np.random.uniform(-0.08, 0.08)
        cost = round(random.uniform(3, 120), 2)
        price = round(cost / (1 - margin), 2)
        products.append({
            "product_id":       pid,
            "product_name":     f"{cat} SKU-{pid:04d}",
            "category":         cat,
            "is_private_label": is_private,
            "cost":             cost,
            "list_price":       price,
            "weight_kg":        round(random.uniform(0.1, 10), 2),
        })
        pid += 1

products_df = pd.DataFrame(products)
products_df.to_csv(f"{OUTPUT_DIR}/products.csv", index=False)
print(f"  ✓ Products: {len(products_df)} rows")


# ─────────────────────────────────────────────
# 3. CUSTOMERS (89,000 unique customers)
# ─────────────────────────────────────────────

N_CUSTOMERS = 89_000

customers = pd.DataFrame({
    "customer_id":    range(1, N_CUSTOMERS + 1),
    "join_date":      [
        datetime(2021, 1, 1) + timedelta(days=random.randint(0, 1094))
        for _ in range(N_CUSTOMERS)
    ],
    "segment":        np.random.choice(
        ["Premium", "Regular", "Occasional"], N_CUSTOMERS, p=[0.15, 0.55, 0.30]
    ),
    "home_region":    np.random.choice(list(REGIONS.keys()), N_CUSTOMERS),
})

customers.to_csv(f"{OUTPUT_DIR}/customers.csv", index=False)
print(f"  ✓ Customers: {len(customers)} rows")


# ─────────────────────────────────────────────
# 4. TRANSACTIONS (~2.4M rows)
# ─────────────────────────────────────────────

START_DATE = datetime(2021, 1, 1)
END_DATE   = datetime(2023, 12, 31)

# Seasonality multiplier by month (Oct-Dec = peak)
MONTH_MULT = {
    1: 0.75, 2: 0.70, 3: 0.80, 4: 0.85, 5: 0.90,  6: 0.95,
    7: 0.95, 8: 0.90, 9: 0.85, 10: 1.10, 11: 1.35, 12: 1.55
}

transactions = []
tx_id = 1

# Midwest stores have stockout issues — inject gaps in top SKUs
midwest_stores = stores_df[stores_df["region"] == "Midwest"]["store_id"].tolist()
top_skus = products_df.sort_values("list_price", ascending=False).head(50)["product_id"].tolist()

current_date = START_DATE
while current_date <= END_DATE:
    month_mult = MONTH_MULT[current_date.month]
    # More transactions on weekends
    dow_mult = 1.3 if current_date.weekday() >= 5 else 1.0
    daily_tx = int(np.random.poisson(650 * month_mult * dow_mult))

    for _ in range(daily_tx):
        store = stores_df.sample(1, weights=stores_df["revenue_mult"]).iloc[0]

        # Midwest + top SKU = simulate stockout (30% chance of no sale)
        if store["store_id"] in midwest_stores:
            product = products_df.sample(1).iloc[0]
            if product["product_id"] in top_skus and random.random() < 0.30:
                current_date += timedelta(days=0)  # skip this transaction
                continue
        else:
            product = products_df.sample(1).iloc[0]

        customer = customers.sample(1).iloc[0]
        qty = np.random.choice([1, 1, 1, 2, 2, 3, 4, 5], p=[0.40, 0.25, 0.15, 0.08, 0.06, 0.03, 0.02, 0.01])
        price = round(product["list_price"] * np.random.uniform(0.92, 1.02), 2)

        transactions.append({
            "transaction_id":   tx_id,
            "transaction_date": current_date.strftime("%Y-%m-%d"),
            "customer_id":      customer["customer_id"],
            "store_id":         int(store["store_id"]),
            "product_id":       int(product["product_id"]),
            "quantity":         int(qty),
            "unit_price":       price,
            "is_return":        random.random() < 0.06,  # 6% return rate
        })
        tx_id += 1

    current_date += timedelta(days=1)

    if len(transactions) % 200_000 == 0:
        print(f"    ... {len(transactions):,} transactions generated")

transactions_df = pd.DataFrame(transactions)
transactions_df.to_csv(f"{OUTPUT_DIR}/transactions.csv", index=False)
print(f"  ✓ Transactions: {len(transactions_df):,} rows")
print("\n✅ All data files generated successfully!")
print(f"   Output directory: {OUTPUT_DIR}")
