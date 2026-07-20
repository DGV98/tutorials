-- Test: customers.email is unique.
-- A row returned = a duplicated email = FAIL.
SELECT email, COUNT(*) AS n_rows
FROM customers
GROUP BY email
HAVING COUNT(*) > 1;
