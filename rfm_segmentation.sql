-- ============================================================
-- OLIST E-COMMERCE: RFM SEGMENTATION
-- ============================================================

SET search_path TO olist;

-- ============================================================
-- STEP 1: COMPUTE RAW RFM METRICS PER CUSTOMER
-- ============================================================

WITH reference_date AS (
    SELECT MAX(order_purchase_timestamp)::DATE + 1 AS ref_date
    FROM clean_orders
),

rfm_raw AS (
    SELECT
        co.customer_unique_id,
        -- recency: days since last purchase (lower = better)
        (SELECT ref_date FROM reference_date) -
            MAX(co.order_purchase_timestamp)::DATE          AS recency_days,
        -- frequency: number of orders
        COUNT(DISTINCT co.order_id)                         AS frequency,
        -- monetary: total spend
        ROUND(SUM(co.payment_value), 2)                     AS monetary
    FROM clean_orders co
    GROUP BY co.customer_unique_id
),

-- ============================================================
-- STEP 2: SCORE EACH DIMENSION 1–4 USING NTILE
-- ============================================================

rfm_scored AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        -- recency score: most recent gets 4
        NTILE(4) OVER (ORDER BY recency_days DESC)      AS r_score,
        -- frequency score: most frequent gets 4
        NTILE(4) OVER (ORDER BY frequency ASC)          AS f_score,
        -- monetary score: highest spend gets 4
        NTILE(4) OVER (ORDER BY monetary ASC)           AS m_score
    FROM rfm_raw
),

-- ============================================================
-- STEP 3: COMBINE INTO RFM TOTAL SCORE + SEGMENT LABELS
-- ============================================================

rfm_segmented AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)   AS rfm_total,

        -- segmentation logic based on score combinations
        CASE
            WHEN r_score = 4 AND f_score >= 3                          THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3                         THEN 'Loyal'
            WHEN r_score >= 3 AND f_score <= 2                         THEN 'Potential Loyalist'
            WHEN r_score = 4 AND f_score = 1                           THEN 'New Customer'
            WHEN r_score = 2 AND f_score >= 2                          THEN 'At Risk'
            WHEN r_score = 2 AND f_score = 1                           THEN 'Needs Attention'
            WHEN r_score = 1 AND f_score >= 3                          THEN 'Cannot Lose Them'
            WHEN r_score = 1 AND f_score = 2                           THEN 'Hibernating'
            WHEN r_score = 1 AND f_score = 1                           THEN 'Lost'
            ELSE                                                            'Others'
        END AS segment
    FROM rfm_scored
)

-- ============================================================
-- STEP 4: FINAL OUTPUT — save as a table for downstream use
-- ============================================================

SELECT * INTO rfm_table FROM rfm_segmented;

-- add index for fast lookups in Phase 4
CREATE INDEX idx_rfm_segment ON rfm_table(segment);
CREATE INDEX idx_rfm_customer ON rfm_table(customer_unique_id);


-- ============================================================
-- SECTION A: INSPECT THE RFM TABLE
-- ============================================================
SET search_path TO olist;
SELECT * FROM rfm_table LIMIT 20;

-- score distribution check — make sure NTILE divided evenly
SELECT
    r_score,
    COUNT(*) AS customers
FROM rfm_table
GROUP BY r_score
ORDER BY r_score;


-- ============================================================
-- SECTION B: SEGMENT SUMMARY — the money slide
-- ============================================================
SET search_path TO olist;
SELECT
    segment,
    COUNT(*)                            AS customer_count,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 2)       AS pct_of_customers,
    ROUND(AVG(recency_days), 0)         AS avg_recency_days,
    ROUND(AVG(frequency), 2)            AS avg_orders,
    ROUND(AVG(monetary), 2)             AS avg_spend,
    ROUND(SUM(monetary), 2)             AS total_revenue
FROM rfm_table
GROUP BY segment
ORDER BY total_revenue DESC;
-- INSIGHT: At Risk have a large customer count and decent revenue, so they are a prime target for retention efforts.
-- Champion will likely be small in count but huge in revenue.


-- ============================================================
-- SECTION C: REVENUE CONCENTRATION
-- ============================================================
-- % of total revenue comes from Champion + Loyal is around 40%

SET search_path TO olist;
SELECT
    segment,
    ROUND(SUM(monetary), 2)                                 AS segment_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 2) AS pct_of_total_revenue
FROM rfm_table
GROUP BY segment
ORDER BY segment_revenue DESC;


-- ============================================================
-- SECTION D: TOP CUSTOMERS IN EACH SEGMENT
-- ============================================================
-- highest-value customer is at At Risk segment with a single order of $13k
SET search_path TO olist;
SELECT
    segment,
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    rfm_total
FROM (
    SELECT *,
        RANK() OVER (PARTITION BY segment ORDER BY monetary DESC) AS rank_in_segment
    FROM rfm_table
) ranked
WHERE rank_in_segment <= 5
ORDER BY segment, monetary DESC;


-- ============================================================
-- SECTION E: GEOGRAPHIC BREAKDOWN BY SEGMENT
-- ============================================================
-- SP states have a large number of potential loyalist but also high count of lost customers
SET search_path TO olist;
SELECT
    co.customer_state,
    rf.segment,
    COUNT(*)            AS customer_count
FROM rfm_table rf
JOIN clean_orders co ON rf.customer_unique_id = co.customer_unique_id
GROUP BY co.customer_state, rf.segment
ORDER BY customer_count DESC
LIMIT 30;
