-- ============================================================
-- OLIST E-COMMERCE: CHURN ANALYSIS & BUSINESS RECOMMENDATIONS
-- ============================================================

SET search_path TO olist;

-- ============================================================
-- SECTION 1: FLAG CHURNED CUSTOMERS
-- ============================================================

-- reference: last date in dataset
SET search_path TO olist;
SELECT MAX(order_purchase_timestamp)::DATE AS last_date FROM clean_orders;

CREATE OR REPLACE VIEW churned_customers AS
WITH last_purchase AS (
    SELECT
        customer_unique_id,
        MAX(order_purchase_timestamp)::DATE AS last_order_date
    FROM clean_orders
    GROUP BY customer_unique_id
),
reference AS (
    SELECT MAX(order_purchase_timestamp)::DATE AS ref_date
    FROM clean_orders
)
SELECT
    lp.customer_unique_id,
    lp.last_order_date,
    r.ref_date,
    (r.ref_date - lp.last_order_date)       AS days_since_last_order,
    CASE
        WHEN (r.ref_date - lp.last_order_date) > 90 THEN 'Churned'
        ELSE 'Active'
    END                                      AS churn_status
FROM last_purchase lp
CROSS JOIN reference r;

-- verify
SELECT
    churn_status,
    COUNT(*)                                            AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM churned_customers
GROUP BY churn_status;


-- ============================================================
-- SECTION 2: CHURN RATE BY RFM SEGMENT
-- ============================================================
-- which segments churn the most?

SET search_path TO olist;
SELECT
    rf.segment,
    COUNT(*)                                                AS total_customers,
    COUNT(*) FILTER (WHERE cc.churn_status = 'Churned')    AS churned_customers,
    ROUND(
        COUNT(*) FILTER (WHERE cc.churn_status = 'Churned')
        * 100.0 / COUNT(*), 2
    )                                                       AS churn_rate_pct,
    ROUND(SUM(rf.monetary), 2)                              AS total_segment_revenue,
    ROUND(
        SUM(rf.monetary) FILTER (WHERE cc.churn_status = 'Churned'), 2
    )                                                       AS churned_revenue
FROM rfm_table rf
JOIN churned_customers cc ON rf.customer_unique_id = cc.customer_unique_id
GROUP BY rf.segment
ORDER BY churned_revenue DESC;
-- INSIGHT: at risk segment has the highest churned revenue (~$3.5M), while cannot lose them and loyal has almost similar number of ~$3m
-- the churn rate percentage is almost at 100% for all segments except for potential loyalist and champion which is around 60% and 21% respectively


-- ============================================================
-- SECTION 3: REVENUE AT RISK SUMMARY
-- ============================================================
-- $12.3m out of $15.4m total revenue is at risk

SET search_path TO olist;
SELECT
    ROUND(SUM(rf.monetary), 2)                              AS total_revenue,
    ROUND(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned'), 2)      AS total_churned_revenue,
    ROUND(
        SUM(rf.monetary) FILTER (WHERE cc.churn_status = 'Churned')
        * 100.0 / SUM(rf.monetary), 2
    )                                                       AS pct_revenue_at_risk
FROM rfm_table rf
JOIN churned_customers cc ON rf.customer_unique_id = cc.customer_unique_id;


-- ============================================================
-- SECTION 4: CHURN BY STATE
-- ============================================================
-- SP dominates churned revenue

SET search_path TO olist;
SELECT
    co.customer_state,
    COUNT(DISTINCT rf.customer_unique_id)                           AS total_customers,
    COUNT(DISTINCT rf.customer_unique_id)
        FILTER (WHERE cc.churn_status = 'Churned')                  AS churned_customers,
    ROUND(
        COUNT(DISTINCT rf.customer_unique_id)
            FILTER (WHERE cc.churn_status = 'Churned')
        * 100.0 /
        COUNT(DISTINCT rf.customer_unique_id), 2
    )                                                               AS churn_rate_pct,
    ROUND(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned'), 2)              AS churned_revenue
FROM rfm_table rf
JOIN churned_customers cc  ON rf.customer_unique_id = cc.customer_unique_id
JOIN clean_orders co       ON rf.customer_unique_id = co.customer_unique_id
GROUP BY co.customer_state
ORDER BY churned_revenue DESC
LIMIT 15;


-- ============================================================
-- SECTION 5: COHORT RETENTION ANALYSIS
-- ============================================================

SET search_path TO olist;
WITH first_orders AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM clean_orders
    GROUP BY customer_unique_id
),
order_months AS (
    SELECT
        co.customer_unique_id,
        DATE_TRUNC('month', co.order_purchase_timestamp)   AS order_month
    FROM clean_orders co
),
cohort_data AS (
    SELECT
        fo.cohort_month,
        om.order_month,
        COUNT(DISTINCT fo.customer_unique_id)              AS customers,
        EXTRACT(YEAR FROM AGE(om.order_month, fo.cohort_month)) * 12 +
        EXTRACT(MONTH FROM AGE(om.order_month, fo.cohort_month)) AS month_number
    FROM first_orders fo
    JOIN order_months om ON fo.customer_unique_id = om.customer_unique_id
    GROUP BY fo.cohort_month, om.order_month
),
cohort_sizes AS (
    SELECT cohort_month, customers AS cohort_size
    FROM cohort_data
    WHERE month_number = 0
)
SELECT
    cd.cohort_month::DATE,
    cd.month_number,
    cd.customers,
    cs.cohort_size,
    ROUND(cd.customers * 100.0 / cs.cohort_size, 2)        AS retention_rate_pct
FROM cohort_data cd
JOIN cohort_sizes cs ON cd.cohort_month = cs.cohort_month
WHERE cd.cohort_month >= '2017-01-01'   -- focus on full-year cohorts
  AND cd.month_number <= 12             -- track up to 12 months
ORDER BY cd.cohort_month, cd.month_number;
-- INSIGHT: January 2017 cohort: 717 customers, only 2 came back in month 1
-- February 2017 cohort: 1,628 customers, only 3 came back in month 1


-- ============================================================
-- SECTION 6: BUSINESS RECOMMENDATIONS
-- ============================================================
-- quantified actions based on the analysis.

-- Prioritize At Risk for re-engagement
-- nearly 6k more than Cannot Lose Them to target and have the highest recovery potential

SET search_path TO olist;
SELECT
    rf.segment,
    COUNT(*)                                AS customers_to_target,
    ROUND(AVG(rf.recency_days), 0)          AS avg_days_since_purchase,
    ROUND(AVG(rf.monetary), 2)              AS avg_customer_value,
    ROUND(SUM(rf.monetary), 2)              AS total_value_at_stake,
    -- recover just 20% of churned At Risk customers:
    ROUND(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned') * 0.20, 2) AS recovery_at_20pct
FROM rfm_table rf
JOIN churned_customers cc ON rf.customer_unique_id = cc.customer_unique_id
WHERE rf.segment IN ('At Risk', 'Cannot Lose Them')
GROUP BY rf.segment
ORDER BY total_value_at_stake DESC;


-- at risk and cannot lose them segments must be the top priority for retention campaigns, but champion and loyal should not be ignored as they also have a significant portion of revenue at risk

SET search_path TO olist;
SELECT
    rf.segment,
    ROUND(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned'), 2)      AS revenue_at_risk,
    ROUND(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned')
        * 100.0 / SUM(SUM(rf.monetary)
        FILTER (WHERE cc.churn_status = 'Churned')) OVER (), 2) AS pct_of_at_risk_revenue,
    -- priority tier for campaign planning
    CASE
        WHEN rf.segment IN ('At Risk', 'Cannot Lose Them') THEN '1 - Immediate Action'
        WHEN rf.segment IN ('Loyal', 'Champion')           THEN '2 - Protect'
        WHEN rf.segment IN ('Hibernating', 'Needs Attention') THEN '3 - Low-cost nudge'
        ELSE                                                    '4 - Write off'
    END AS campaign_priority
FROM rfm_table rf
JOIN churned_customers cc ON rf.customer_unique_id = cc.customer_unique_id
WHERE cc.churn_status = 'Churned'
GROUP BY rf.segment
ORDER BY revenue_at_risk DESC;
