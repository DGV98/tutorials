-- Test: every order references an existing customer (referential integrity).
-- SQLite only enforces FKs when PRAGMA foreign_keys = ON, so we verify.
SELECT o.order_id, o.customer_id
FROM orders AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM customers AS c
    WHERE c.customer_id = o.customer_id
);
