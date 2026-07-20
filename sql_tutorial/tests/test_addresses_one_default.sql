-- Test: every customer who has addresses has exactly one default address.
-- Checkout picks "the default" — two defaults or zero would break it.
SELECT customer_id, SUM(is_default) AS n_defaults
FROM addresses
GROUP BY customer_id
HAVING SUM(is_default) <> 1;
