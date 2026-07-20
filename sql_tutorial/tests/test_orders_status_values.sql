-- Test: orders.status takes only the six documented values.
-- A new status appearing upstream should break loudly, not corrupt reports.
SELECT DISTINCT status
FROM orders
WHERE status NOT IN
    ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned');
