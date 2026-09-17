-- ============================================================
-- Project 1: Retail Sales Performance Dashboard
-- File: 02_sales_aggregations.sql
-- Purpose: Core business KPIs and sales metrics
-- ============================================================


-- ─────────────────────────────────────────────
-- 1. MONTHLY REVENUE TREND WITH YoY COMPARISON
-- ─────────────────────────────────────────────

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', transaction_date)         AS month,
        EXTRACT(YEAR  FROM transaction_date)           AS year,
        EXTRACT(MONTH FROM transaction_date)           AS month_num,
        ROUND(SUM(quantity * unit_price), 2)           AS revenue,
        COUNT(*)                                       AS transactions,
        COUNT(DISTINCT customer_id)                    AS unique_customers
    FROM transactions
    GROUP BY 1, 2, 3
),
yoy AS (
    SELECT
        cur.month,
        cur.revenue                                    AS current_revenue,
        prev.revenue                                   AS prior_year_revenue,
        ROUND(
            (cur.revenue - prev.revenue) / NULLIF(prev.revenue, 0) * 100, 1
        )                                              AS yoy_growth_pct
    FROM monthly_revenue cur
    LEFT JOIN monthly_revenue prev
        ON cur.year     = prev.year + 1
       AND cur.month_num = prev.month_num
)
SELECT * FROM yoy ORDER BY month;


-- ─────────────────────────────────────────────
-- 2. REGIONAL PERFORMANCE SCORECARD
-- ─────────────────────────────────────────────

SELECT
    s.region,
    COUNT(DISTINCT s.store_id)               AS store_count,
    ROUND(SUM(t.quantity * t.unit_price), 0) AS total_revenue,
    ROUND(AVG(t.quantity * t.unit_price), 2) AS avg_transaction_value,
    COUNT(DISTINCT t.customer_id)            AS unique_customers,
    COUNT(*)                                 AS total_transactions,
    ROUND(
        SUM(t.quantity * t.unit_price) / COUNT(DISTINCT s.store_id), 0
    )                                        AS revenue_per_store,
    -- Rank regions by revenue
    RANK() OVER (ORDER BY SUM(t.quantity * t.unit_price) DESC) AS revenue_rank
FROM transactions t
JOIN stores s ON t.store_id = s.store_id
GROUP BY s.region
ORDER BY revenue_rank;


-- ─────────────────────────────────────────────
-- 3. PRODUCT CATEGORY MARGIN ANALYSIS
-- ─────────────────────────────────────────────

SELECT
    p.category,
    p.is_private_label,
    COUNT(DISTINCT t.product_id)             AS sku_count,
    SUM(t.quantity)                          AS units_sold,
    ROUND(SUM(t.quantity * t.unit_price), 0) AS gross_revenue,
    ROUND(SUM(t.quantity * p.cost), 0)       AS cogs,
    ROUND(
        (SUM(t.quantity * t.unit_price) - SUM(t.quantity * p.cost))
        / NULLIF(SUM(t.quantity * t.unit_price), 0) * 100, 1
    )                                        AS gross_margin_pct,
    ROUND(AVG(t.unit_price), 2)              AS avg_selling_price,
    -- Share of total revenue
    ROUND(
        SUM(t.quantity * t.unit_price)
        / SUM(SUM(t.quantity * t.unit_price)) OVER () * 100, 1
    )                                        AS revenue_share_pct
FROM transactions t
JOIN products p ON t.product_id = p.product_id
GROUP BY p.category, p.is_private_label
ORDER BY gross_revenue DESC;


-- ─────────────────────────────────────────────
-- 4. PARETO ANALYSIS: TOP CUSTOMERS BY REVENUE
-- ─────────────────────────────────────────────

WITH customer_revenue AS (
    SELECT
        customer_id,
        ROUND(SUM(quantity * unit_price), 2) AS lifetime_revenue,
        COUNT(*)                              AS total_orders,
        MIN(transaction_date)                 AS first_order,
        MAX(transaction_date)                 AS last_order
    FROM transactions
    GROUP BY customer_id
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY lifetime_revenue DESC) AS revenue_rank,
        SUM(lifetime_revenue) OVER (ORDER BY lifetime_revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                             AS running_revenue,
        SUM(lifetime_revenue) OVER ()                 AS grand_total
    FROM customer_revenue
)
SELECT
    revenue_rank,
    lifetime_revenue,
    running_revenue,
    ROUND(running_revenue / grand_total * 100, 1) AS cumulative_pct_revenue,
    ROUND(revenue_rank::NUMERIC / COUNT(*) OVER () * 100, 1) AS pct_of_customers
FROM ranked
WHERE revenue_rank <= 100   -- top 100 customers
   OR revenue_rank % 1000 = 0  -- sample remaining at 1000-customer intervals
ORDER BY revenue_rank;


-- ─────────────────────────────────────────────
-- 5. STOCKOUT PROXY: ZERO-SALES DAYS BY STORE/SKU
-- ─────────────────────────────────────────────

-- Identifies store-SKU combinations with suspiciously long gaps
-- between sales (proxy for out-of-stock events)

WITH store_sku_dates AS (
    SELECT
        store_id,
        product_id,
        transaction_date,
        LAG(transaction_date) OVER (
            PARTITION BY store_id, product_id
            ORDER BY transaction_date
        ) AS prev_sale_date
    FROM transactions
),
gaps AS (
    SELECT
        store_id,
        product_id,
        transaction_date,
        prev_sale_date,
        transaction_date - prev_sale_date AS days_gap
    FROM store_sku_dates
    WHERE prev_sale_date IS NOT NULL
)
SELECT
    g.store_id,
    s.store_name,
    s.region,
    g.product_id,
    p.product_name,
    p.category,
    COUNT(*) FILTER (WHERE days_gap > 7)  AS stockout_events_7d,
    COUNT(*) FILTER (WHERE days_gap > 14) AS stockout_events_14d,
    MAX(days_gap)                          AS max_gap_days,
    ROUND(AVG(days_gap), 1)               AS avg_gap_days
FROM gaps g
JOIN stores   s ON g.store_id  = s.store_id
JOIN products p ON g.product_id = p.product_id
GROUP BY 1, 2, 3, 4, 5, 6
HAVING COUNT(*) FILTER (WHERE days_gap > 7) >= 3
ORDER BY stockout_events_14d DESC, max_gap_days DESC
LIMIT 50;
