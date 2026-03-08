-- ============================================================
-- OLIST E-COMMERCE: DATA EXPLORATION & CLEANING
-- ============================================================

SET search_path TO olist;

-- ============================================================
-- SECTION 1: DATASET OVERVIEW
-- ============================================================

-- how many unique customers, orders, products, sellers?
SELECT
    (SELECT COUNT(DISTINCT customer_unique_id) FROM customers)  AS unique_customers,
    (SELECT COUNT(*)                            FROM orders)     AS total_orders,
    (SELECT COUNT(DISTINCT product_id)          FROM products)   AS unique_products,
    (SELECT COUNT(DISTINCT seller_id)           FROM sellers)    AS unique_sellers;

-- date range of the dataset
SELECT
    MIN(order_purchase_timestamp)::DATE AS earliest_order,
    MAX(order_purchase_timestamp)::DATE AS latest_order,
    MAX(order_purchase_timestamp)::DATE - MIN(order_purchase_timestamp)::DATE AS days_span
FROM orders;

-- order status breakdown — how many orders are in each state?
SELECT
    order_status,
    COUNT(*)                                    AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;
-- INSIGHT: only 'delivered' orders should be used for RFM analysis.
-- 'cancelled', 'unavailable' orders will be excluded downstream.


-- ============================================================
-- SECTION 2: NULL CHECKS
-- ============================================================

-- customers table
SELECT
    COUNT(*)                                                AS total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL)             AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL)      AS null_unique_id,
    COUNT(*) FILTER (WHERE customer_city IS NULL)           AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL)          AS null_state
FROM customers;

-- orders table — focus on timestamps used in RFM
SELECT
    COUNT(*)                                                            AS total_rows,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL)            AS null_purchase_ts,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)       AS null_delivered_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)                   AS null_approved_at,
    COUNT(*) FILTER (WHERE customer_id IS NULL)                         AS null_customer_id
FROM orders;
-- NOTE: null delivered dates are expected for non-delivered orders.
-- will filter to order_status = 'delivered' in RFM, which resolves this.

-- order items table
SELECT
    COUNT(*)                                            AS total_rows,
    COUNT(*) FILTER (WHERE price IS NULL)               AS null_price,
    COUNT(*) FILTER (WHERE freight_value IS NULL)       AS null_freight,
    COUNT(*) FILTER (WHERE product_id IS NULL)          AS null_product_id,
    COUNT(*) FILTER (WHERE seller_id IS NULL)           AS null_seller_id
FROM order_items;

-- order payments table
SELECT
    COUNT(*)                                                AS total_rows,
    COUNT(*) FILTER (WHERE payment_value IS NULL)           AS null_payment_value,
    COUNT(*) FILTER (WHERE payment_type IS NULL)            AS null_payment_type
FROM order_payments;


-- ============================================================
-- SECTION 3: DUPLICATE CHECKS
-- ============================================================

-- are there any duplicate order_ids?
SELECT order_id, COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
-- expected: 0 rows (orders has a PK on order_id)

-- customers: how many customer_ids map to the same person (customer_unique_id)?
-- this is expected, one person can place multiple orders with different customer_ids
SELECT
    customer_unique_id,
    COUNT(customer_id) AS order_profiles
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(customer_id) > 1
ORDER BY order_profiles DESC
LIMIT 10;

-- how many total customers placed more than one order?
SELECT COUNT(*) AS multi_order_customers
FROM (
    SELECT customer_unique_id
    FROM customers
    GROUP BY customer_unique_id
    HAVING COUNT(customer_id) > 1
) sub;


-- ============================================================
-- SECTION 4: DATE VALIDATION
-- ============================================================

-- are there any orders where delivered date is BEFORE purchase date? (data error)
SELECT
    order_id,
    order_purchase_timestamp::DATE                          AS purchased,
    order_delivered_customer_date::DATE                     AS delivered,
    EXTRACT(DAY FROM order_delivered_customer_date - order_purchase_timestamp)::INT AS days_to_deliver
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND (order_delivered_customer_date - order_purchase_timestamp) > INTERVAL '180 days'
ORDER BY days_to_deliver DESC;


-- ============================================================
-- SECTION 5: REVENUE SANITY CHECK
-- ============================================================

-- total revenue across the dataset
SELECT
    ROUND(SUM(payment_value), 2)        AS total_revenue_brl,
    ROUND(AVG(payment_value), 2)        AS avg_order_value,
    ROUND(MIN(payment_value), 2)        AS min_order_value,
    ROUND(MAX(payment_value), 2)        AS max_order_value
FROM order_payments;

-- are there any zero or negative payment values? (suspicious)
SELECT COUNT(*) AS suspicious_payments
FROM order_payments
WHERE payment_value <= 0;

-- payment type breakdown
SELECT
    payment_type,
    COUNT(*)                                                    AS transaction_count,
    ROUND(SUM(payment_value), 2)                                AS total_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)         AS pct_of_transactions
FROM order_payments
GROUP BY payment_type
ORDER BY transaction_count DESC;


-- ============================================================
-- SECTION 6: DEFINE THE CLEAN ANALYSIS DATASET
-- ============================================================

CREATE OR REPLACE VIEW clean_orders AS
SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.customer_id,
    cu.customer_city,
    cu.customer_state,
    COALESCE(p.payment_value, 0) AS payment_value
FROM orders o
JOIN customers cu ON o.customer_id = cu.customer_id
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM order_payments
    GROUP BY order_id
) p ON o.order_id = p.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND COALESCE(p.payment_value, 0) > 0;

-- verify the clean dataset
SELECT
    COUNT(*)                        AS clean_orders,
    COUNT(DISTINCT customer_unique_id) AS unique_customers,
    ROUND(SUM(payment_value), 2)    AS total_revenue
FROM clean_orders;
-- INSIGHT: over 96k clean orders with 3k unique customers and total revenue of $15M
