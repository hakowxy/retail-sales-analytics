-- Builds a small star schema from the raw order export.
-- Run with DuckDB from the repo root:  duckdb superstore.duckdb < sql/01_star_schema.sql

CREATE OR REPLACE TABLE raw_orders AS
SELECT * FROM read_csv('data/superstore_sales.csv', header = true, dateformat = '%m/%d/%Y');

-- Dimensions -----------------------------------------------------------------

CREATE OR REPLACE TABLE dim_customer AS
SELECT
    row_number() OVER (ORDER BY "Customer Name", "Customer Segment", "Province") AS customer_key,
    "Customer Name"    AS customer_name,
    "Customer Segment" AS segment,
    "Province"         AS province,
    "Region"           AS region
FROM (
    SELECT DISTINCT "Customer Name", "Customer Segment", "Province", "Region"
    FROM raw_orders
);

CREATE OR REPLACE TABLE dim_product AS
SELECT
    row_number() OVER (ORDER BY "Product Category", "Product Sub-Category", "Product Name") AS product_key,
    "Product Name"         AS product_name,
    "Product Category"     AS category,
    "Product Sub-Category" AS sub_category,
    "Product Container"    AS container
FROM (
    SELECT DISTINCT "Product Name", "Product Category", "Product Sub-Category", "Product Container"
    FROM raw_orders
);

CREATE OR REPLACE TABLE dim_date AS
SELECT
    d::DATE                          AS date_key,
    year(d)                          AS year,
    quarter(d)                       AS quarter,
    month(d)                         AS month,
    strftime(d, '%Y-%m')             AS year_month,
    dayofweek(d)                     AS day_of_week
FROM range(DATE '2009-01-01', DATE '2013-01-01', INTERVAL 1 DAY) AS t(d);

-- Fact -----------------------------------------------------------------------

CREATE OR REPLACE TABLE fact_order_line AS
SELECT
    o."Row ID"                                   AS order_line_id,
    o."Order ID"                                 AS order_id,
    o."Order Date"                               AS order_date,
    o."Ship Date"                                AS ship_date,
    c.customer_key,
    p.product_key,
    o."Order Priority"                           AS order_priority,
    o."Ship Mode"                                AS ship_mode,
    o."Order Quantity"                           AS quantity,
    o."Unit Price"                               AS unit_price,
    o."Discount"                                 AS discount,
    o."Sales"                                    AS sales,
    o."Profit"                                   AS profit,
    o."Shipping Cost"                            AS shipping_cost
FROM raw_orders o
JOIN dim_customer c
  ON  c.customer_name = o."Customer Name"
  AND c.segment       = o."Customer Segment"
  AND c.province      = o."Province"
JOIN dim_product p
  ON  p.product_name  = o."Product Name"
  AND p.category      = o."Product Category"
  AND p.sub_category  = o."Product Sub-Category"
  AND p.container     = o."Product Container";

-- Sanity check: every raw row should land in the fact table exactly once.
SELECT
    (SELECT count(*) FROM raw_orders)      AS raw_rows,
    (SELECT count(*) FROM fact_order_line) AS fact_rows;
