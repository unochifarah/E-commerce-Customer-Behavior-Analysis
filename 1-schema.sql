-- ============================================================
-- OLIST E-COMMERCE: SCHEMA SETUP
-- ============================================================

-- create a dedicated schema to keep things clean
CREATE SCHEMA IF NOT EXISTS olist;
SET search_path TO olist;

-- --------------------------------------------------------
-- 1. CUSTOMERS
-- --------------------------------------------------------
DROP TABLE IF EXISTS customers CASCADE;
CREATE TABLE customers (
    customer_id             VARCHAR(50) PRIMARY KEY,
    customer_unique_id      VARCHAR(50) NOT NULL,
    customer_zip_code       VARCHAR(10),
    customer_city           VARCHAR(100),
    customer_state          CHAR(2)
);

-- --------------------------------------------------------
-- 2. SELLERS
-- --------------------------------------------------------
DROP TABLE IF EXISTS sellers CASCADE;
CREATE TABLE sellers (
    seller_id               VARCHAR(50) PRIMARY KEY,
    seller_zip_code         VARCHAR(10),
    seller_city             VARCHAR(100),
    seller_state            CHAR(2)
);

-- --------------------------------------------------------
-- 3. PRODUCTS
-- --------------------------------------------------------
DROP TABLE IF EXISTS products CASCADE;
CREATE TABLE products (
    product_id              VARCHAR(50) PRIMARY KEY,
    product_category_name   VARCHAR(100),
    product_name_length     INT,
    product_description_length INT,
    product_photos_qty      INT,
    product_weight_g        NUMERIC,
    product_length_cm       NUMERIC,
    product_height_cm       NUMERIC,
    product_width_cm        NUMERIC
);

-- --------------------------------------------------------
-- 4. PRODUCT CATEGORY NAME TRANSLATION
-- --------------------------------------------------------
DROP TABLE IF EXISTS product_category_translation CASCADE;
CREATE TABLE product_category_translation (
    product_category_name           VARCHAR(100) PRIMARY KEY,
    product_category_name_english   VARCHAR(100)
);

-- --------------------------------------------------------
-- 5. ORDERS  (central fact table)
-- --------------------------------------------------------
DROP TABLE IF EXISTS orders CASCADE;
CREATE TABLE orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50) REFERENCES customers(customer_id),
    order_status                    VARCHAR(30),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

-- --------------------------------------------------------
-- 6. ORDER ITEMS
-- --------------------------------------------------------
DROP TABLE IF EXISTS order_items CASCADE;
CREATE TABLE order_items (
    order_id            VARCHAR(50) REFERENCES orders(order_id),
    order_item_id       INT,          -- line number within the order
    product_id          VARCHAR(50)   REFERENCES products(product_id),
    seller_id           VARCHAR(50)   REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- --------------------------------------------------------
-- 7. ORDER PAYMENTS
-- --------------------------------------------------------
DROP TABLE IF EXISTS order_payments CASCADE;
CREATE TABLE order_payments (
    order_id                VARCHAR(50) REFERENCES orders(order_id),
    payment_sequential      INT,
    payment_type            VARCHAR(30),
    payment_installments    INT,
    payment_value           NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- --------------------------------------------------------
-- 8. ORDER REVIEWS
-- --------------------------------------------------------
DROP TABLE IF EXISTS order_reviews CASCADE;
CREATE TABLE order_reviews (
    review_id               VARCHAR(50),
    order_id                VARCHAR(50) REFERENCES orders(order_id),
    review_score            SMALLINT CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_orders_customer  ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status    ON orders(order_status);
CREATE INDEX IF NOT EXISTS idx_orders_purchase  ON orders(order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_items_product    ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_items_seller     ON order_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_payments_order   ON order_payments(order_id);
CREATE INDEX IF NOT EXISTS idx_reviews_order    ON order_reviews(order_id);
CREATE INDEX IF NOT EXISTS idx_customers_unique ON customers(customer_unique_id);

-- ============================================================
-- VERIFY
-- ============================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'olist'
ORDER BY table_name;
