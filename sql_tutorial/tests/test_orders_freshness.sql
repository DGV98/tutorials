-- Test: the orders table is fresh (newest order on/after 2026-07-01).
-- Against a live database you would use a rolling window instead:
--     HAVING MAX(ordered_at) < datetime('now', '-2 days')
-- The course dataset is frozen at 2026-07-14, so we pin the threshold.
SELECT MAX(ordered_at) AS newest_order
FROM orders
HAVING MAX(ordered_at) < '2026-07-01';
