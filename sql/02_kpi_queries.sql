-- KPI queries on top of the star schema built in 01_star_schema.sql.

-- 1. Yearly headline KPIs
SELECT
    year(order_date)                       AS year,
    round(sum(sales))                      AS sales,
    round(sum(profit))                     AS profit,
    round(sum(profit) / sum(sales) * 100, 1) AS margin_pct,
    count(DISTINCT order_id)               AS orders,
    round(sum(sales) / count(DISTINCT order_id)) AS avg_order_value
FROM fact_order_line
GROUP BY 1
ORDER BY 1;

-- 2. Profitability by category and ship mode
--    (furniture shipped by delivery truck is the big profit leak)
SELECT
    p.category,
    f.ship_mode,
    round(sum(f.sales))                        AS sales,
    round(sum(f.profit))                       AS profit,
    round(sum(f.profit) / sum(f.sales) * 100, 1) AS margin_pct,
    round(avg(f.shipping_cost), 1)             AS avg_shipping_cost
FROM fact_order_line f
JOIN dim_product p USING (product_key)
GROUP BY 1, 2
ORDER BY sales DESC;

-- 3. Sub-categories that lose money
SELECT
    p.category,
    p.sub_category,
    round(sum(f.sales))                        AS sales,
    round(sum(f.profit))                       AS profit,
    round(sum(f.profit) / sum(f.sales) * 100, 1) AS margin_pct
FROM fact_order_line f
JOIN dim_product p USING (product_key)
GROUP BY 1, 2
HAVING sum(f.profit) < 0
ORDER BY profit;

-- 4. Margin by discount band
SELECT
    CASE
        WHEN discount <= 0.02 THEN '0-2%'
        WHEN discount <= 0.05 THEN '3-5%'
        WHEN discount <= 0.08 THEN '6-8%'
        ELSE '9%+'
    END                                        AS discount_band,
    count(*)                                   AS order_lines,
    round(sum(profit) / sum(sales) * 100, 1)   AS margin_pct,
    round(avg(CASE WHEN profit < 0 THEN 1 ELSE 0 END) * 100, 1) AS loss_making_lines_pct
FROM fact_order_line
GROUP BY 1
ORDER BY 1;

-- 5. Region ranking with year-over-year growth (window function)
WITH region_year AS (
    SELECT c.region, year(f.order_date) AS year, sum(f.sales) AS sales, sum(f.profit) AS profit
    FROM fact_order_line f
    JOIN dim_customer c USING (customer_key)
    GROUP BY 1, 2
)
SELECT
    region,
    year,
    round(sales)                                                         AS sales,
    round(profit / sales * 100, 1)                                       AS margin_pct,
    round((sales / lag(sales) OVER (PARTITION BY region ORDER BY year) - 1) * 100, 1) AS yoy_growth_pct,
    rank() OVER (PARTITION BY year ORDER BY sales DESC)                  AS sales_rank
FROM region_year
ORDER BY year, sales_rank;

-- 6. Customer concentration: share of sales from the top 20% of customers
WITH customer_sales AS (
    SELECT c.customer_name, sum(f.sales) AS sales
    FROM fact_order_line f
    JOIN dim_customer c USING (customer_key)
    GROUP BY 1
),
ranked AS (
    SELECT *, ntile(5) OVER (ORDER BY sales DESC) AS quintile
    FROM customer_sales
)
SELECT
    quintile,
    count(*)                                         AS customers,
    round(sum(sales) / (SELECT sum(sales) FROM customer_sales) * 100, 1) AS share_of_sales_pct
FROM ranked
GROUP BY 1
ORDER BY 1;
