-- ============================================================
-- OLIST E-COMMERCE: DATA LOADING
-- ============================================================

SET search_path TO olist;

-- 1. Customers
\copy customers FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_customers_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 2. Sellers
\copy sellers FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_sellers_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 3. Products
\copy products FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_products_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 4. Category translation
\copy product_category_translation FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\product_category_name_translation.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 5. Orders  (must come before items/payments/reviews)
\copy orders FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_orders_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 6. Order items
\copy order_items FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_order_items_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 7. Order payments
\copy order_payments FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_order_payments_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 8. Order reviews
\copy order_reviews FROM '"E:\GitHub\E-commerce Customer Behavior Analysis\dataset\olist_order_reviews_dataset.csv"'
    WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');


-- ============================================================
-- QUICK SANITY CHECK
-- ============================================================
SELECT
    'customers'                 AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers',             COUNT(*) FROM sellers
UNION ALL SELECT 'products',            COUNT(*) FROM products
UNION ALL SELECT 'orders',              COUNT(*) FROM orders
UNION ALL SELECT 'order_items',         COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',      COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',       COUNT(*) FROM order_reviews
ORDER BY tbl;
