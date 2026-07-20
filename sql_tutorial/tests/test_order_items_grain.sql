-- Test: order_items has exactly one row per (order_id, product_id).
-- Guards every revenue query in the course against silent double-counting.
SELECT order_id, product_id, COUNT(*) AS n_rows
FROM order_items
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;
