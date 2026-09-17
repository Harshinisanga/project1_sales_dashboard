-- ============================================================
-- Project 1: Retail Sales Performance Dashboard
-- File: 01_data_exploration.sql
-- Purpose: Initial data profiling and quality assessment
-- Author: [Your Name]
-- ============================================================

-- ─────────────────────────────────────────────
-- 1. DATASET OVERVIEW
-- ─────────────────────────────────────────────

-- Row counts across all tables
SELECT 'transactions' AS table_name, COUNT(*) AS row_count FROM transactions
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'stores', COUNT(*) FROM stores
UNION ALL
SELECT 'customers', COUNT(*) FROM customers;

-- Date range of transactions
SELECT
    MIN(transaction_date)   AS earliest_date,
    MAX(transaction_date)   AS latest_date,
    COUNT(DISTINCT DATE_TRUNC('month', transaction_date)) AS months_covered,
    COUNT(DISTINCT transaction_date) AS active_days
FROM transactions;


-- ─────────────────────────────────────────────
-- 2. DATA QUALITY CHECKS
-- ─────────────────────────────────────────────

-- Null value audit across transactions
SELECT
    COUNT(*)                                         AS total_rows,
    SUM(CASE WHEN transaction_id IS NULL THEN 1 END) AS null_transaction_id,
    SUM(CASE WHEN customer_id   IS NULL THEN 1 END)  AS null_customer_id,
    SUM(CASE WHEN product_id    IS NULL THEN 1 END)  AS null_product_id,
    SUM(CASE WHEN store_id      IS NULL THEN 1 END)  AS null_store_id,
    SUM(CASE WHEN quantity      IS NULL THEN 1 END)  AS null_quantity,
    SUM(CASE WHEN unit_price    IS NULL THEN 1 END)  AS null_unit_price,
    SUM(CASE WHEN transaction_date IS NULL THEN 1 END) AS null_date
FROM transactions;

-- Duplicate transaction check
SELECT
    transaction_id,
    COUNT(*) AS occurrences
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- Negative/zero revenue check (data anomalies)
SELECT
    COUNT(*) AS anomalous_rows,
    SUM(quantity * unit_price) AS total_anomalous_revenue
FROM transactions
WHERE quantity <= 0 OR unit_price <= 0;

-- Price outlier detection (unit_price > 3 SD from category mean)
WITH category_stats AS (
    SELECT
        p.category,
        AVG(t.unit_price)    AS avg_price,
        STDDEV(t.unit_price) AS sd_price
    FROM transactions t
    JOIN products p ON t.product_id = p.product_id
    GROUP BY p.category
)
SELECT
    t.transaction_id,
    p.category,
    t.unit_price,
    cs.avg_price,
    cs.sd_price,
    ABS(t.unit_price - cs.avg_price) / NULLIF(cs.sd_price, 0) AS z_score
FROM transactions t
JOIN products p  ON t.product_id = p.product_id
JOIN category_stats cs ON p.category = cs.category
WHERE ABS(t.unit_price - cs.avg_price) / NULLIF(cs.sd_price, 0) > 3
ORDER BY z_score DESC;


-- ─────────────────────────────────────────────
-- 3. DISTRIBUTION ANALYSIS
-- ─────────────────────────────────────────────

-- Revenue distribution by year
SELECT
    EXTRACT(YEAR FROM transaction_date) AS year,
    COUNT(*)                            AS num_transactions,
    COUNT(DISTINCT customer_id)         AS unique_customers,
    COUNT(DISTINCT store_id)            AS active_stores,
    ROUND(SUM(quantity * unit_price), 2) AS total_revenue,
    ROUND(AVG(quantity * unit_price), 2) AS avg_transaction_value
FROM transactions
GROUP BY 1
ORDER BY 1;

-- Revenue by day of week (seasonality signal)
SELECT
    TO_CHAR(transaction_date, 'Day') AS day_of_week,
    EXTRACT(DOW FROM transaction_date) AS day_num,
    COUNT(*) AS transactions,
    ROUND(AVG(quantity * unit_price), 2) AS avg_revenue_per_tx
FROM transactions
GROUP BY 1, 2
ORDER BY 2;

-- Store coverage: are all stores consistently active?
SELECT
    s.store_id,
    s.store_name,
    s.region,
    COUNT(DISTINCT DATE_TRUNC('month', t.transaction_date)) AS active_months,
    MIN(t.transaction_date) AS first_sale,
    MAX(t.transaction_date) AS last_sale
FROM stores s
LEFT JOIN transactions t ON s.store_id = t.store_id
GROUP BY 1, 2, 3
ORDER BY active_months ASC;
