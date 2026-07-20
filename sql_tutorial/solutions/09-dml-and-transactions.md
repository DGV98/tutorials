# Module 9 Solutions — DML & Transactions

All solutions run against a **fresh copy** of the database
(`cp shop.db scratch.db`) so the module's own demos don't shift the numbers.
If you solved the exercises on the copy you used while reading the module,
auto-assigned ids (new `supplier_id`, `product_id`, `payment_id`) and a few
prices will differ — that's expected, not wrong.

```bash
cp shop.db scratch.db
```

## Warm-up

### Exercise 1 — new supplier, id in one statement

```sql
INSERT INTO suppliers (name, country, contact_email)
VALUES ('Tundra Trading ApS', 'Denmark', 'hello@tundratrading.dk')
RETURNING supplier_id, name, country;
```

```text
╭─────────────┬────────────────────┬─────────╮
│ supplier_id │        name        │ country │
╞═════════════╪════════════════════╪═════════╡
│          41 │ Tundra Trading ApS │ Denmark │
╰─────────────┴────────────────────┴─────────╯
```

`RETURNING` makes the INSERT itself report the auto-assigned key — no second
statement, no race. A common wrong approach is `SELECT MAX(supplier_id) FROM
suppliers` afterwards: on a busy multi-connection system another insert can
land between your two statements and you'd read *its* id.

### Exercise 2 — two products, one statement

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-25-0351', 'Tundra Down Booties', 25, 41,  54.90, 22.10, 1, '2026-07-15'),
    ('NK-02-0352', 'Tundra Bivy Sack',     2, 41, 189.00, 88.40, 1, '2026-07-15');

SELECT product_id, sku, name, category_id, unit_price
FROM products
WHERE supplier_id = 41;
```

```text
╭────────────┬────────────┬─────────────────────┬─────────────┬────────────╮
│ product_id │    sku     │        name         │ category_id │ unit_price │
╞════════════╪════════════╪═════════════════════╪═════════════╪════════════╡
│        351 │ NK-25-0351 │ Tundra Down Booties │          25 │       54.9 │
│        352 │ NK-02-0352 │ Tundra Bivy Sack    │           2 │      189.0 │
╰────────────┴────────────┴─────────────────────┴─────────────┴────────────╯
```

One multi-row INSERT is atomic: either both products exist afterwards or
neither does. The verification SELECT filters on the supplier id from
exercise 1.

### Exercise 3 — jackets dry-run, then the cut

Dry-run first — the count is your contract with yourself:

```sql
SELECT COUNT(*) AS jackets_over_300
FROM products
WHERE category_id = 23
  AND is_active = 1
  AND unit_price > 300;
```

```text
╭──────────────────╮
│ jackets_over_300 │
╞══════════════════╡
│                9 │
╰──────────────────╯
```

```sql
UPDATE products
SET unit_price = ROUND(unit_price * 0.90, 2)
WHERE category_id = 23
  AND is_active = 1
  AND unit_price > 300;

SELECT changes() AS rows_updated;
```

```text
╭──────────────╮
│ rows_updated │
╞══════════════╡
│            9 │
╰──────────────╯
```

Dry-run said 9, `changes()` says 9 — the UPDATE hit exactly the intended rows.
Beware that this statement is **not idempotent**: run it twice and the jackets
get cut 10% twice (and some may drop under the 300 threshold in between,
making the damage uneven). Multiplicative updates are run-exactly-once
operations — wrap them in a transaction and check counts before committing.

## Core

### Exercise 4 — refund with RETURNING

```sql
BEGIN;

UPDATE orders
SET status = 'returned'
WHERE order_id = 5964 AND status = 'delivered';

INSERT INTO payments (order_id, amount, method, status, paid_at)
SELECT oi.order_id,
       -ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2),
       'refund',
       'captured',
       '2026-07-16 10:00:00'
FROM order_items oi
WHERE oi.order_id = 5964
RETURNING payment_id, order_id, amount, method;

COMMIT;

SELECT status FROM orders WHERE order_id = 5964;
```

```text
╭────────────┬──────────┬────────┬────────╮
│ payment_id │ order_id │ amount │ method │
╞════════════╪══════════╪════════╪════════╡
│       6168 │     5964 │ -78.52 │ refund │
╰────────────┴──────────┴────────┴────────╯
╭──────────╮
│  status  │
╞══════════╡
│ returned │
╰──────────╯
```

The `INSERT ... SELECT` computes the canonical item revenue and negates it —
the refund amount comes from the data, not from a number typed by hand.
`RETURNING` shows the new `payment_id` without a follow-up query, and the
transaction guarantees status flip and refund land together. Common wrong
approach: computing the amount in a separate SELECT and pasting it into a
`VALUES` insert — it works until someone edits the order between your two
steps, or fat-fingers the paste.

### Exercise 5 — a price change done right (SCD-2)

```sql
BEGIN;

UPDATE price_history
SET valid_to = '2026-07-16 00:00:00'
WHERE product_id = (SELECT product_id FROM products WHERE sku = 'NK-11-0004')
  AND valid_to IS NULL;

INSERT INTO price_history (product_id, price, valid_from, valid_to)
SELECT product_id, 289.00, '2026-07-16 00:00:00', NULL
FROM products
WHERE sku = 'NK-11-0004';

UPDATE products
SET unit_price = 289.00
WHERE sku = 'NK-11-0004';

COMMIT;

SELECT ph.price_id, ph.price, ph.valid_from, ph.valid_to
FROM price_history ph
JOIN products p USING (product_id)
WHERE p.sku = 'NK-11-0004'
ORDER BY ph.valid_from;
```

```text
╭──────────┬────────┬─────────────────────┬─────────────────────╮
│ price_id │ price  │     valid_from      │      valid_to       │
╞══════════╪════════╪═════════════════════╪═════════════════════╡
│        9 │ 243.81 │ 2023-08-07 19:55:08 │ 2023-10-24 00:27:22 │
│       10 │ 267.64 │ 2023-10-24 00:27:22 │ 2026-07-16 00:00:00 │
│      723 │  289.0 │ 2026-07-16 00:00:00 │                     │
╰──────────┴────────┴─────────────────────┴─────────────────────╯
```

The history stays contiguous: the old current row now ends exactly where the
new row begins, and exactly one row per product has `valid_to IS NULL`. Order
matters — close the old row *before* inserting the new one, or the invariant
"one open row per product" is briefly violated (harmless inside a transaction,
but close-first keeps every intermediate state valid). Skipping the third
statement is the classic bug: `products.unit_price` must stay equal to the
open history row, per the dataset's convention.

### Exercise 6 — mini catalog-feed upsert, run twice

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-08-0002', 'Wall Harness',      8,  9, 92.00, 48.26, 1, '2026-07-16'),
    ('NK-12-0005', 'Stride Ski Poles', 12, 40, 84.90, 41.44, 1, '2026-07-16'),
    ('NK-13-0356', 'Polaris Compass',  13, 38, 44.90, 18.00, 1, '2026-07-16')
ON CONFLICT (sku) DO UPDATE SET
    unit_price = excluded.unit_price;

SELECT COUNT(*) AS n_products, ROUND(SUM(unit_price), 2) AS price_checksum
FROM products;
```

```text
╭────────────┬────────────────╮
│ n_products │ price_checksum │
╞════════════╪════════════════╡
│        353 │       72184.23 │
╰────────────┴────────────────╯
```

Second run — same statement:

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-08-0002', 'Wall Harness',      8,  9, 92.00, 48.26, 1, '2026-07-16'),
    ('NK-12-0005', 'Stride Ski Poles', 12, 40, 84.90, 41.44, 1, '2026-07-16'),
    ('NK-13-0356', 'Polaris Compass',  13, 38, 44.90, 18.00, 1, '2026-07-16')
ON CONFLICT (sku) DO UPDATE SET
    unit_price = excluded.unit_price;

SELECT COUNT(*) AS n_products, ROUND(SUM(unit_price), 2) AS price_checksum
FROM products;
```

```text
╭────────────┬────────────────╮
│ n_products │ price_checksum │
╞════════════╪════════════════╡
│        353 │       72184.23 │
╰────────────┴────────────────╯
```

Identical count and checksum: run one inserted `NK-13-0356` and updated two
prices; run two updated the same rows to values they already had. Note the
`DO UPDATE SET` deliberately lists **only** `unit_price` — the exercise's
policy was that a price feed may not touch anything else on existing rows.
(`VALUES`-based upserts don't need the `WHERE true` trick; that's only for
`INSERT ... SELECT`.)

### Exercise 7 — idempotent monthly backfill for 2025

```sql
CREATE TABLE monthly_revenue (
    month         TEXT PRIMARY KEY,
    gross_revenue REAL NOT NULL
);

INSERT INTO monthly_revenue (month, gross_revenue)
SELECT strftime('%Y-%m', o.ordered_at) AS month,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
GROUP BY strftime('%Y-%m', o.ordered_at)
ON CONFLICT (month) DO UPDATE SET
    gross_revenue = excluded.gross_revenue;

SELECT COUNT(*) AS months, ROUND(SUM(gross_revenue), 2) AS total_2025
FROM monthly_revenue;
```

```text
╭────────┬────────────╮
│ months │ total_2025 │
╞════════╪════════════╡
│     12 │ 1129344.79 │
╰────────┴────────────╯
```

Second run:

```sql
INSERT INTO monthly_revenue (month, gross_revenue)
SELECT strftime('%Y-%m', o.ordered_at) AS month,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
GROUP BY strftime('%Y-%m', o.ordered_at)
ON CONFLICT (month) DO UPDATE SET
    gross_revenue = excluded.gross_revenue;

SELECT COUNT(*) AS months, ROUND(SUM(gross_revenue), 2) AS total_2025
FROM monthly_revenue;
```

```text
╭────────┬────────────╮
│ months │ total_2025 │
╞════════╪════════════╡
│     12 │ 1129344.79 │
╰────────┴────────────╯
```

Gross revenue follows the canonical definition (item revenue, cancelled orders
excluded, returned included). The PRIMARY KEY on `month` plus `ON CONFLICT DO
UPDATE` makes reruns rewrite each month with the same value instead of
duplicating rows. (This query already has a `WHERE`, so the SQLite
`INSERT ... SELECT ... ON CONFLICT` parser quirk doesn't bite.) The windowed
delete-then-insert from the module's Pitfall 3 is an equally valid answer.
The common wrong approach — a bare `INSERT ... SELECT` with no PK and no
conflict clause — doubles all of 2025 on the first retry.

### Exercise 8 — retention delete with dry-run

Dry-run:

```sql
SELECT COUNT(*) AS to_delete
FROM reviews r
JOIN products p USING (product_id)
WHERE r.review_text IS NULL
  AND p.is_active = 0;
```

```text
╭───────────╮
│ to_delete │
╞═══════════╡
│        62 │
╰───────────╯
```

Delete inside a transaction, compare, commit:

```sql
BEGIN;

DELETE FROM reviews
WHERE review_text IS NULL
  AND product_id IN (SELECT product_id FROM products WHERE is_active = 0);

SELECT changes() AS rows_deleted;

COMMIT;

SELECT COUNT(*) AS reviews_remaining FROM reviews;
```

```text
╭──────────────╮
│ rows_deleted │
╞══════════════╡
│           62 │
╰──────────────╯
╭───────────────────╮
│ reviews_remaining │
╞═══════════════════╡
│              3269 │
╰───────────────────╯
```

62 predicted, 62 deleted, and 3,331 − 62 = 3,269 remain. SQLite's DELETE has
no direct join, so the products condition moves into an `IN` (or `EXISTS`)
subquery — in PostgreSQL you could also write `DELETE FROM reviews USING
products WHERE ...`. Had `changes()` disagreed with the dry-run, the
transaction was our exit: `ROLLBACK` and investigate.

## Challenge

### Exercise 9 — predict, then run: error inside a transaction

**Prediction:** 20.00. In SQLite an error aborts only the failing *statement*;
the transaction stays open and the CLI (without `.bail on`) continues with the
next statement. So the first UPDATE applies, the INSERT fails and is
discarded, the second UPDATE applies, and COMMIT makes both updates permanent.

```bash
cat > predict_a.sql <<'SQL'
BEGIN;
UPDATE products SET unit_price = 10.00 WHERE product_id = 5;
INSERT INTO products (sku, name, category_id, supplier_id,
                      unit_price, unit_cost, is_active, introduced_at)
VALUES ('NK-21-0006', 'Duplicate', 21, 36, 1, 1, 1, '2026-07-15');
UPDATE products SET unit_price = 20.00 WHERE product_id = 5;
COMMIT;
SQL
sqlite3 -box scratch.db < predict_a.sql
sqlite3 -box scratch.db "SELECT product_id, unit_price FROM products WHERE product_id = 5;"
```

```text
Error near line 3: UNIQUE constraint failed: products.sku
╭────────────┬────────────╮
│ product_id │ unit_price │
╞════════════╪════════════╡
│          5 │       20.0 │
╰────────────┴────────────╯
```

**In PostgreSQL:** the duplicate-key error puts the whole transaction into an
aborted state; the second UPDATE fails with *"current transaction is aborted,
commands ignored until end of transaction block"*, and the final `COMMIT` is
silently turned into a rollback. Product 5 would still cost 92.68. Same
script, opposite outcome — which is exactly why application code must treat
*any* error inside a transaction as "roll back and retry", on both engines.

### Exercise 10 — predict, then run: two connections

**Prediction:** 2.00. Connection one opens a transaction and never commits —
when the process exits, SQLite rolls the open transaction back, so the 1.00
never becomes durable. Connection two runs its UPDATE in **autocommit** mode:
no `BEGIN` means the statement is its own transaction, committed the moment it
finishes.

```bash
sqlite3 scratch.db "BEGIN; UPDATE products SET unit_price = 1.00 WHERE product_id = 6;"
sqlite3 scratch.db "UPDATE products SET unit_price = 2.00 WHERE product_id = 6;"
sqlite3 -box scratch.db "SELECT product_id, unit_price FROM products WHERE product_id = 6;"
```

```text
╭────────────┬────────────╮
│ product_id │ unit_price │
╞════════════╪════════════╡
│          6 │        2.0 │
╰────────────┴────────────╯
```

The two rules: (1) **a connection that closes with an open transaction rolls
it back** — durability belongs to COMMIT, not to having executed the
statement; (2) **without BEGIN, every statement autocommits** and is
immediately permanent.

### Exercise 11 — the daily orders export pipeline

Create the feed file:

```bash
cat > orders_export_2026-07-15.csv <<'CSV'
order_id,customer_id,address_id,status,shipping_cost,ordered_at
6000,226,316,returned,0.0,2025-07-13 11:15:40
6001,718,1004,pending,4.90,2026-07-15 08:12:00
6002,202,282,paid,0.0,2026-07-15 09:47:00
CSV
```

Stage it (loose table, cleared before every import):

```sql
CREATE TABLE stg_orders_export (
    order_id      INTEGER,
    customer_id   INTEGER,
    address_id    INTEGER,
    status        TEXT,
    shipping_cost REAL,
    ordered_at    TEXT
);

SELECT COUNT(*) AS staged_rows FROM stg_orders_export;
```

```text
╭─────────────╮
│ staged_rows │
╞═════════════╡
│           0 │
╰─────────────╯
```

```bash
sqlite3 -box scratch.db \
  "DELETE FROM stg_orders_export;" \
  ".import --csv --skip 1 orders_export_2026-07-15.csv stg_orders_export" \
  "SELECT COUNT(*) AS staged_rows FROM stg_orders_export;"
```

```text
╭─────────────╮
│ staged_rows │
╞═════════════╡
│           3 │
╰─────────────╯
```

Validate (three assertions chosen: unknown customer, unknown address, illegal
status — plus the duplicate check for good measure):

```sql
SELECT 'unknown customer_id' AS problem, COUNT(*) AS n
FROM stg_orders_export
WHERE customer_id NOT IN (SELECT customer_id FROM customers)
UNION ALL
SELECT 'unknown address_id', COUNT(*)
FROM stg_orders_export
WHERE address_id NOT IN (SELECT address_id FROM addresses)
UNION ALL
SELECT 'duplicate order_id in feed', COUNT(*)
FROM (SELECT order_id FROM stg_orders_export GROUP BY order_id HAVING COUNT(*) > 1)
UNION ALL
SELECT 'illegal status', COUNT(*)
FROM stg_orders_export
WHERE status NOT IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned');
```

```text
╭────────────────────────────┬───╮
│          problem           │ n │
╞════════════════════════════╪═══╡
│ unknown customer_id        │ 0 │
│ unknown address_id         │ 0 │
│ duplicate order_id in feed │ 0 │
│ illegal status             │ 0 │
╰────────────────────────────┴───╯
```

All zeros — apply the batch atomically. Only `status` and `shipping_cost` may
change for existing orders:

```sql
BEGIN;

INSERT INTO orders (order_id, customer_id, address_id, status, shipping_cost, ordered_at)
SELECT order_id, customer_id, address_id, status, shipping_cost, ordered_at
FROM stg_orders_export
WHERE true
ON CONFLICT (order_id) DO UPDATE SET
    status        = excluded.status,
    shipping_cost = excluded.shipping_cost;

COMMIT;

SELECT (SELECT COUNT(*) FROM orders)                          AS n_orders,
       (SELECT status FROM orders WHERE order_id = 6000)      AS order_6000_status;
```

```text
╭──────────┬───────────────────╮
│ n_orders │ order_6000_status │
╞══════════╪═══════════════════╡
│     6002 │ returned          │
╰──────────┴───────────────────╯
```

Second run of the same upsert — the idempotency proof:

```sql
INSERT INTO orders (order_id, customer_id, address_id, status, shipping_cost, ordered_at)
SELECT order_id, customer_id, address_id, status, shipping_cost, ordered_at
FROM stg_orders_export
WHERE true
ON CONFLICT (order_id) DO UPDATE SET
    status        = excluded.status,
    shipping_cost = excluded.shipping_cost;

SELECT (SELECT COUNT(*) FROM orders)                          AS n_orders,
       (SELECT status FROM orders WHERE order_id = 6000)      AS order_6000_status;
```

```text
╭──────────┬───────────────────╮
│ n_orders │ order_6000_status │
╞══════════╪═══════════════════╡
│     6002 │ returned          │
╰──────────┴───────────────────╯
```

Stable at 6,002 orders: 6001 and 6002 inserted once, order 6000 restated to
`returned`, and the retry changed nothing. This is the module's whole arc in
one exercise: staging isolates the raw file, assertions catch garbage before
it reaches `orders`, the transaction applies the batch atomically, and the
`ON CONFLICT` key makes the job safe to run any number of times. Note the
`WHERE true` — this is the `INSERT ... SELECT ... ON CONFLICT` form that
SQLite's parser refuses without it.
