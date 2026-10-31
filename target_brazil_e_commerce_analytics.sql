-- ====================================================================
-- Project: Target Brazil E-Commerce Operations Analysis (2016-2018)
-- Description: Complete SQL script containing schema exploration, 
--              customer demographics, financial metrics, and shipping logistics.
-- ====================================================================

-- 1. INITIAL EXPLORATION & TIME RANGE ANALYSIS
-- Get the time range between which the orders were placed.
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date,
    DATEDIFF(MAX(order_purchase_timestamp), MIN(order_purchase_timestamp)) AS total_days_span,
    TIMEDIFF(MAX(order_purchase_timestamp), MIN(order_purchase_timestamp)) AS total_time_span
FROM orders;

-- Count active cities and states of customers who ordered during the active period.
SELECT 
    COUNT(DISTINCT a.customer_city) AS count_of_city, 
    COUNT(DISTINCT a.customer_state) AS count_of_state
FROM customers AS a
JOIN orders AS b
    ON a.customer_id = b.customer_id
WHERE order_purchase_timestamp BETWEEN '2016-01-01 00:00:00' AND '2018-12-31 23:59:59';


-- ====================================================================
-- 2. IN-DEPTH TRENDS & SEASONALITY
-- ====================================================================

-- Identify trends and year-over-year growth in orders.
WITH YearlyOrders AS (
    SELECT
        YEAR(order_purchase_timestamp) AS order_year,
        COUNT(order_id) AS total_orders
    FROM orders
    GROUP BY YEAR(order_purchase_timestamp)
)
SELECT
    order_year, 
    total_orders,
    total_orders - LAG(total_orders) OVER (ORDER BY order_year) AS raw_difference,
    ROUND((total_orders - LAG(total_orders) OVER (ORDER BY order_year)) * 100.0 / 
          LAG(total_orders) OVER (ORDER BY order_year), 2
    ) AS yoy_growth_percentage
FROM YearlyOrders
ORDER BY order_year;

-- Detect monthly seasonality across years.
SELECT
    MONTH(order_purchase_timestamp) AS order_month,
    COUNT(CASE WHEN YEAR(order_purchase_timestamp) = 2016 THEN order_id END) AS orders_2016,
    COUNT(CASE WHEN YEAR(order_purchase_timestamp) = 2017 THEN order_id END) AS orders_2017,
    COUNT(CASE WHEN YEAR(order_purchase_timestamp) = 2018 THEN order_id END) AS orders_2018
FROM orders
GROUP BY MONTH(order_purchase_timestamp)
ORDER BY order_month;

-- Determine the time of day when Brazilian customers mostly place orders.
SELECT
    CASE 
        WHEN HOUR(order_purchase_timestamp) BETWEEN 0 AND 5 THEN 'Dawn'
        WHEN HOUR(order_purchase_timestamp) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN HOUR(order_purchase_timestamp) BETWEEN 12 AND 17 THEN 'Afternoon'
        ELSE 'Night'
    END AS time_of_day,
    COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER(), 2) AS percentage_of_total
FROM orders
GROUP BY time_of_day
ORDER BY total_orders DESC;


-- ====================================================================
-- 3. GEOGRAPHIC & CUSTOMER VALUE SEGMENTATION
-- ====================================================================

-- Month-on-month number of orders placed in each state.
SELECT 
    a.customer_state AS name_of_state,
    MONTH(b.order_purchase_timestamp) AS order_month, 
    COUNT(b.order_id) AS total_order,
    COUNT(CASE WHEN YEAR(b.order_purchase_timestamp) = 2016 THEN order_id END) AS orders_2016,
    COUNT(CASE WHEN YEAR(b.order_purchase_timestamp) = 2017 THEN order_id END) AS orders_2017,
    COUNT(CASE WHEN YEAR(b.order_purchase_timestamp) = 2018 THEN order_id END) AS orders_2018
FROM customers AS a
JOIN orders AS b
    ON a.customer_id = b.customer_id
GROUP BY a.customer_state, order_month
ORDER BY order_month;

-- Distribution of customers and purchasing power tiers across all states.
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_id) AS grand_total_customers,
    COUNT(DISTINCT CASE WHEN a.payment_value < 150 THEN c.customer_id END) AS low_value_buyers,
    COUNT(DISTINCT CASE WHEN a.payment_value BETWEEN 150 AND 300 THEN c.customer_id END) AS medium_value_buyers,
    COUNT(DISTINCT CASE WHEN a.payment_value > 300 THEN c.customer_id END) AS high_value_buyers
FROM payments AS a
JOIN orders AS b
    ON a.order_id = b.order_id
JOIN customers AS c
    ON b.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY grand_total_customers DESC;


-- ====================================================================
-- 4. FINANCIAL & ECONOMIC IMPACT ANALYSIS
-- ====================================================================

-- Monthly Gross Revenue, Product Value, Freight Outflow, and Credit Installments.
SELECT
    YEAR(b.order_purchase_timestamp) AS financial_year,
    MONTH(b.order_purchase_timestamp) AS financial_month,
    ROUND(SUM(p.payment_value), 2) AS total_gross_revenue,
    ROUND(SUM(oi.price), 2) AS total_product_value,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_costs,
    ROUND((SUM(oi.freight_value) * 100.0 / SUM(p.payment_value)), 2) AS freight_revenue_ratio,
    ROUND(AVG(p.payment_installments), 1) AS avg_payment_installments
FROM orders AS b
JOIN order_items AS oi
    ON b.order_id = oi.order_id
JOIN payments AS p
    ON b.order_id = p.order_id
GROUP BY YEAR(b.order_purchase_timestamp),
         MONTH(b.order_purchase_timestamp)
ORDER BY financial_year, financial_month;

-- YoY comparative increase in transaction values (Jan-Aug window comparison).
WITH YearlyTotals AS (
    SELECT
        SUM(CASE WHEN YEAR(b.order_purchase_timestamp) = 2017 THEN a.payment_value ELSE 0 END) AS cost_2017,
        SUM(CASE WHEN YEAR(b.order_purchase_timestamp) = 2018 THEN a.payment_value ELSE 0 END) AS cost_2018
    FROM payments AS a
    JOIN orders AS b
        ON a.order_id = b.order_id
    WHERE MONTH(b.order_purchase_timestamp) BETWEEN 1 AND 8
)
SELECT
    ROUND(cost_2017, 2) AS total_cost_2017_jan_aug,
    ROUND(cost_2018, 2) AS total_cost_2018_jan_aug,
    ROUND((cost_2018 - cost_2017), 2) AS absolute_increase,
    ROUND(((cost_2018 - cost_2017) * 100.0 / cost_2017), 2) AS percentage_increase
FROM YearlyTotals;

-- Total and average value of order prices and freight profiles grouped by state.
SELECT 
    c.customer_state, 
    SUM(a.price) AS total_order_price, 
    AVG(a.price) AS average_order_price, 
    SUM(a.freight_value) AS total_freight_value,
    AVG(a.freight_value) AS average_frieght_value
FROM order_items AS a
JOIN orders AS b
    ON a.order_id = b.order_id
JOIN customers AS c
    ON b.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_order_price DESC;


-- ====================================================================
-- 5. SALES, FREIGHT, AND DELIVERY TIME PERFORMANCE
-- ====================================================================

-- Calculate individual fulfillment turnaround times and SLA variance gaps.
SELECT 
    order_id,
    DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) AS delivery_time_days,
    DATEDIFF(order_estimated_delivery_date, order_delivered_customer_date) AS diff_estimated_vs_actual_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- Identify the top 5 states with the highest vs. lowest average freight values.
WITH RankedStates AS (
    SELECT
        c.customer_state,
        AVG(a.freight_value) AS avg_freight,
        ROW_NUMBER() OVER (ORDER BY AVG(a.freight_value) DESC) AS rank_desc,
        ROW_NUMBER() OVER (ORDER BY AVG(a.freight_value) ASC) AS rank_asc
    FROM order_items AS a
    JOIN orders AS b ON a.order_id = b.order_id
    JOIN customers AS c ON b.customer_id = c.customer_id
    GROUP BY c.customer_state
)
SELECT
    MAX(CASE WHEN rank_desc <= 5 THEN customer_state END) AS top_state,
    MAX(CASE WHEN rank_desc <= 5 THEN avg_freight END) AS top_avg_freight,
    MAX(CASE WHEN rank_asc <= 5 THEN customer_state END) AS bottom_state,
    MAX(CASE WHEN rank_asc <= 5 THEN avg_freight END) AS bottom_avg_freight
FROM RankedStates
GROUP BY (CASE WHEN rank_desc <= 5 THEN rank_desc ELSE rank_asc END)
LIMIT 5;

-- Contrast Slowest (Highest) vs. Fastest (Lowest) average delivery times by state.
(
    SELECT
        c.customer_state AS state,
        AVG(DATEDIFF(b.order_delivered_customer_date, b.order_purchase_timestamp)) AS avg_delivery_time_days,
        'Slowest (Highest)' AS category
    FROM orders AS b
    JOIN customers AS c ON b.customer_id = c.customer_id
    WHERE b.order_status = 'delivered'
      AND b.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
    ORDER BY avg_delivery_time_days DESC 
    LIMIT 5
)
UNION ALL
(
    SELECT
        c.customer_state AS state,
        AVG(DATEDIFF(b.order_delivered_customer_date, b.order_purchase_timestamp)) AS avg_delivery_time_days,
        'Fastest (Lowest)' AS category
    FROM orders AS b
    JOIN customers AS c ON b.customer_id = c.customer_id
    WHERE b.order_status = 'delivered'
      AND b.order_delivered_customer_date IS NOT NULL
    GROUP BY c.customer_state
    ORDER BY avg_delivery_time_days ASC 
    LIMIT 5
);

-- Analyze delivery buffer accuracy against customer expectations.
SELECT
    c.customer_state AS state,
    AVG(DATEDIFF(b.order_estimated_delivery_date, b.order_delivered_customer_date)) AS avg_days_ahead_of_schedule
FROM orders AS b
JOIN customers AS c ON b.customer_id = c.customer_id
WHERE b.order_status = 'delivered'
  AND b.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING avg_days_ahead_of_schedule > 0
ORDER BY avg_days_ahead_of_schedule DESC
LIMIT 5;


-- ====================================================================
-- 6. PAYMENT CHANNELS & INSTALLMENT PREFERENCES
-- ====================================================================

-- Month-on-month volume breakdown across payment channels.
SELECT
    MONTH(o.order_purchase_timestamp) AS order_month,
    p.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders AS o
JOIN payments AS p 
    ON o.order_id = p.order_id
GROUP BY order_month, p.payment_type
ORDER BY order_month ASC, total_orders DESC;

-- Distribution profile of payment installments.
SELECT
    payment_installments,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER(), 2) AS percentage_of_total
FROM payments
GROUP BY payment_installments
ORDER BY total_orders DESC;
```ojs