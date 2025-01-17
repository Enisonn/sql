SELECT 
product_name || ', ' || product_size|| ' (' || product_qty_type || ')'
FROM product;

SELECT 
    product_name
    || ', ' 
    || COALESCE(product_size, '') 
    || ' (' 
    || COALESCE(product_qty_type, 'unit') 
    || ')' AS product_details
FROM product;


--Windowed Functions
/* 1. Write a query that selects from the customer_purchases table and numbers each customer’s  
visits to the farmer’s market (labeling each market date with a different number). 
Each customer’s first visit is labeled 1, second visit is labeled 2, etc. 

You can either display all rows in the customer_purchases table, with the counter changing on
each new market date for each customer, or select only the unique market dates per customer 
(without purchase details) and number those visits. 
HINT: One of these approaches uses ROW_NUMBER() and one uses DENSE_RANK(). */

---WINDOW functions part one

SELECT
    customer_id,
    market_date,
    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY market_date
    ) AS visit_number
FROM (
    SELECT DISTINCT customer_id, market_date
    FROM customer_purchases
) AS unique_visits
ORDER BY customer_id, market_date;

--/* 2. Reverse the numbering of the query from a part so each customer’s most recent visit is labeled 1, 
then write another query that uses this one as a subquery (or temp table) and filters the results to 
only the customer’s most recent visit. */
---WINDOW functions part two

SELECT
    customer_id,
    market_date,
    ROW_NUMBER() OVER (
        PARTITION BY customer_id
        ORDER BY market_date DESC
    ) AS reversed_visit_number
FROM customer_purchases;

/* 3. Using a COUNT() window function, include a value along with each row of the 
customer_purchases table that indicates how many different times that customer has purchased that product_id. */
---WINDOW functions part three

SELECT
    customer_id,
    product_id,
    market_date,
    COUNT(*) OVER (
        PARTITION BY customer_id, product_id
    ) AS total_purchases_for_product
FROM customer_purchases;



--String Manipulations 
/* 1. Some product names in the product table have descriptions like "Jar" or "Organic". 
These are separated from the product name with a hyphen. 
Create a column using SUBSTR (and a couple of other commands) that captures these, but is otherwise NULL. 
Remove any trailing or leading whitespaces. Don't just use a case statement for each product! 

| product_name               | description |
|----------------------------|-------------|
| Habanero Peppers - Organic | Organic     |

Hint: you might need to use INSTR(product_name,'-') to find the hyphens. INSTR will help split the column. */

SELECT
    product_name,
    CASE 
        WHEN INSTR(product_name, '-') > 0 THEN 
            TRIM(SUBSTR(
                product_name, 
                INSTR(product_name, '-') + 1
            ))
        ELSE 
            NULL
    END AS product_description
FROM product;

/* 2. Filter the query to show any product_size value that contain a number with REGEXP. */


--Unions 
/* 1. Using a UNION, write a query that displays the market dates with the highest and lowest total sales.

HINT: There are a possibly a few ways to do this query, but if you're struggling, try the following: 
1) Create a CTE/Temp Table to find sales values grouped dates; 
2) Create another CTE/Temp table with a rank windowed function on the previous query to create 
"best day" and "worst day"; 
3) Query the second temp table twice, once for the best day, once for the worst day, 
with a UNION binding them. */

WITH total_sales_by_date AS (
    SELECT
        market_date,
        SUM(quantity * cost_to_customer_per_qty) AS total_sales
    FROM customer_purchases
    GROUP BY market_date
),
ranked_dates AS (
    SELECT
        market_date,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) AS best_day_rank,
        RANK() OVER (ORDER BY total_sales ASC)  AS worst_day_rank
    FROM total_sales_by_date
)
SELECT 
    'Highest' AS sale_type,
    market_date,
    total_sales
FROM ranked_dates
WHERE best_day_rank = 1

UNION

SELECT
    'Lowest' AS sale_type,
    market_date,
    total_sales
FROM ranked_dates
WHERE worst_day_rank = 1;

--Section three cross join  
/* SECTION 3 */

-- Cross Join
/*1. Suppose every vendor in the `vendor_inventory` table had 5 of each of their products to sell to **every** 
customer on record. How much money would each vendor make per product? 
Show this by vendor_name and product name, rather than using the IDs.

HINT: Be sure you select only relevant columns and rows. 
Remember, CROSS JOIN will explode your table rows, so CROSS JOIN should likely be a subquery. 
Think a bit about the row counts: how many distinct vendors, product names are there (x)?
How many customers are there (y). 
Before your final group by you should have the product of those two queries (x*y).  */


-- 1) Create a CTE ("vendor_products") of distinct (vendor, product) pairs,
--    pulling in the vendor_name, product_name, and original_price.
WITH vendor_products AS (
    SELECT DISTINCT
        v.vendor_id,
        v.vendor_name,
        p.product_id,
        p.product_name,
        vi.original_price
    FROM vendor_inventory vi
    JOIN vendor v 
      ON vi.vendor_id = v.vendor_id
    JOIN product p 
      ON vi.product_id = p.product_id
),

-- 2) Create a CTE ("all_customers") listing every customer
all_customers AS (
    SELECT c.customer_id
    FROM customer c
),

-- 3) CROSS JOIN the two sets:
--    For every (vendor, product) pair, we get every customer.
vendor_product_customers AS (
    SELECT
        vp.vendor_id,
        vp.vendor_name,
        vp.product_id,
        vp.product_name,
        vp.original_price,
        ac.customer_id
    FROM vendor_products vp
    CROSS JOIN all_customers ac
)

-- 4) GROUP BY vendor_name and product_name.
--    Each customer buys 5 units, so total_units_sold = 5 * count_of_customers
--    total_revenue = (5 * count_of_customers) * original_price.
SELECT
    vendor_name,
    product_name,
    5 * COUNT(*) AS total_units_sold,
    5 * COUNT(*) * original_price AS total_revenue
FROM vendor_product_customers
GROUP BY 
    vendor_name,
    product_name,
    original_price
ORDER BY 
    vendor_name,
    product_name;

--Insert  part 1
/*1.  Create a new table "product_units". 
This table will contain only products where the `product_qty_type = 'unit'`. 
It should use all of the columns from the product table, as well as a new column for the `CURRENT_TIMESTAMP`.  
Name the timestamp column `snapshot_timestamp`. */

SELECT
    p.*,
    CURRENT_TIMESTAMP AS snapshot_timestamp
FROM product p
WHERE p.product_qty_type = 'unit';

--- part 2
/*2. Using `INSERT`, add a new row to the product_units table (with an updated timestamp). 
This can be any product you desire (e.g. add another record for Apple Pie). */
INSERT INTO product_units (
    product_id,
    product_name,
    product_size,
    product_qty_type,
    snapshot_timestamp
)
VALUES (
    999,                
    'Apple Pie Deluxe', -
    'Large',            -
    'unit',             
    CURRENT_TIMESTAMP  
);

-- DELETE
/* 1. Delete the older record for the whatever product you added. 

HINT: If you don't specify a WHERE clause, you are going to have a bad time.*/
DELETE FROM product_units
WHERE product_id = 999; 

-- UPDATE
/* 1.We want to add the current_quantity to the product_units table. 
First, add a new column, current_quantity to the table using the following syntax.


