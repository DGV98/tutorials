# Module 12 Solutions — SQL Style & Structure

Reference refactors and tests. For the refactoring exercises (1, 4) any layout that follows the style guide and returns identical rows is correct — compare structure, not whitespace. All queries here are read-only against `shop.db`, except Exercise 10, which writes only to a disposable copy under `/tmp`.

## Warm-up

### Exercise 1 — Opt-in rate by country — reformat

```sql
SELECT
    country,
    SUM(CASE WHEN marketing_opt_in = 1 THEN 1 ELSE 0 END)      AS opted_in,
    COUNT(*)                                                   AS customers,
    ROUND(100.0 * SUM(CASE WHEN marketing_opt_in = 1 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                       AS opt_in_pct
FROM customers
GROUP BY country
ORDER BY opt_in_pct DESC
LIMIT 5;
```

```text
╭────────────────┬──────────┬───────────┬────────────╮
│    country     │ opted_in │ customers │ opt_in_pct │
╞════════════════╪══════════╪═══════════╪════════════╡
│ Switzerland    │       14 │        31 │       45.2 │
│ Norway         │       43 │        98 │       43.9 │
│ United Kingdom │       30 │        69 │       43.5 │
│ Denmark        │       43 │       101 │       42.6 │
│ Germany        │       47 │       115 │       40.9 │
╰────────────────┴──────────┴───────────┴────────────╯
```

Uppercase keywords, one clause per line, one select-item per line, every column named (`optin` → `opted_in`, `pct` → `opt_in_pct`), and `ORDER BY` uses the alias instead of an ordinal. The `CASE` sum still appears twice — acceptable in a single-table aggregate this small; a CTE would be ceremony without payoff here (contrast Exercise 4, where repetition means *recomputation per row*).

### Exercise 2 — Naming critique

Violations in the sketch:

1. `Return` — singular where the schema is plural, CamelCase where the schema is `snake_case`, and a reserved-ish keyword in most dialects. Triple fault.
2. `id` — bare key name; the convention is `table_id` so FK and PK names match across joins.
3. `order` — a hard reserved word (`ORDER BY`), unusable without quoting; also fails the `table_id` FK convention.
4. `desc` — reserved word (`ORDER BY ... DESC`).
5. `approved` — a 0/1 flag without the `is_` predicate prefix.
6. `Date` — mixed case, reserved-ish, and says nothing about *which* moment (requested? approved?). Timestamps take `_at`.

Compliant rewrite:

```text
CREATE TABLE returns (
    return_id     INTEGER PRIMARY KEY,
    order_id      INTEGER REFERENCES orders(order_id),
    reason        TEXT,
    is_approved   INTEGER,          -- 0/1
    requested_at  TEXT
);
```

### Exercise 3 — Header block and grain

```text
-- =====================================================================
-- Report:  Monthly product spend per customer
-- Grain:   one row per (customer, calendar month) in which the customer
--          placed at least one non-cancelled order — months with no
--          orders produce NO row, not a zero row
-- Notes:   spend = item revenue (quantity * unit_price * (1 - discount))
--          of non-cancelled orders, per DATASET.md's canonical
--          definition. Shipping is EXCLUDED, so this is not the sum of
--          canonical order totals; returned orders are included.
-- =====================================================================
```

The grain trap: it's not "one row per customer" (customer 2 appears twice in the first six rows) and not "one row per customer per month" either — inactive months are absent, which matters the moment someone tries to compute month-over-month deltas or averages "per month". The `spend` note matters because DATASET.md defines *order total* as items + shipping; a reader reconciling this against order totals would otherwise chase a phantom discrepancy.

## Core

### Exercise 4 — New vs returning customers — pipeline refactor

```sql
-- New vs returning customers per month, 2025.
-- Grain: one row per calendar month.
-- New = the month of the customer's first-ever non-cancelled order;
-- a customer counts at most once per month (order count is irrelevant).
WITH
non_cancelled_orders AS (         -- import: the only base table we need
    SELECT
        customer_id,
        strftime('%Y-%m', ordered_at) AS order_month
    FROM orders
    WHERE status <> 'cancelled'
),

customer_months AS (              -- one row per customer per active month
    SELECT DISTINCT customer_id, order_month
    FROM non_cancelled_orders
),

first_order_month AS (            -- each customer's first-ever active month
    SELECT customer_id, MIN(order_month) AS cohort_month
    FROM non_cancelled_orders
    GROUP BY customer_id
)

SELECT
    cm.order_month,
    SUM(CASE WHEN cm.order_month = f.cohort_month THEN 1 ELSE 0 END) AS new_customers,
    SUM(CASE WHEN cm.order_month > f.cohort_month THEN 1 ELSE 0 END) AS returning_customers
FROM customer_months   AS cm
JOIN first_order_month AS f ON f.customer_id = cm.customer_id
WHERE cm.order_month BETWEEN '2025-01' AND '2025-12'
GROUP BY cm.order_month
ORDER BY cm.order_month;
```

```text
╭─────────────┬───────────────┬─────────────────────╮
│ order_month │ new_customers │ returning_customers │
╞═════════════╪═══════════════╪═════════════════════╡
│ 2025-01     │             5 │                  66 │
│ 2025-02     │            11 │                  62 │
│ 2025-03     │            11 │                  83 │
│ 2025-04     │            18 │                  78 │
│ 2025-05     │            19 │                  77 │
│ 2025-06     │            13 │                 109 │
│ 2025-07     │            15 │                 116 │
│ 2025-08     │            11 │                 105 │
│ 2025-09     │            15 │                 121 │
│ 2025-10     │            21 │                 107 │
│ 2025-11     │            25 │                 174 │
│ 2025-12     │            26 │                 218 │
╰─────────────┴───────────────┴─────────────────────╯
```

Identical twelve rows. The `status <> 'cancelled'` rule now lives in exactly one place (the import CTE), each logical CTE is one idea with a stated grain, and the final SELECT only classifies and counts. Bonus answer: the original runs the correlated `MIN(...)` subquery once *per distinct customer-month row*, rescanning `orders` each time; `first_order_month` computes every customer's minimum in a single `GROUP BY` pass. Same answer, one scan instead of thousands.

(Also note the sanity cross-check available for free: the `new_customers` column exactly matches the `cohort_size` column of the module's cohort query for Jan–Jun 2025 — 5, 11, 11, 18, 19, 13 — two independently structured queries agreeing on a number is cheap evidence both are right.)

### Exercise 5 — Every delivered order has a shipment

Save as `tests/test_delivered_have_shipment.sql`:

```sql
-- Test: every delivered order has at least one shipment.
-- An order can't be 'delivered' if nothing was ever shipped.
SELECT o.order_id, o.status
FROM orders AS o
WHERE o.status = 'delivered'
  AND NOT EXISTS (
      SELECT 1 FROM shipments AS s WHERE s.order_id = o.order_id
  );
```

```text
(zero rows returned — pass)
```

A `NOT EXISTS` anti-join (Module 4) in violating-rows form. Once the file is in `tests/`, `bash tests/run_tests.sh` picks it up automatically (the runner globs `tests/test_*.sql`) and reports seven `PASS` lines. Common wrong approach: `WHERE order_id NOT IN (SELECT order_id FROM shipments)` — it happens to work here, but the Module 4 rule stands: one NULL in that subquery and the test would silently pass forever, which for a *test* is the worst possible failure mode.

### Exercise 6 — Payments reconcile to delivered order totals

Save as `tests/test_payments_reconcile.sql`:

```sql
-- Test: for every delivered order, captured payments sum to the
-- canonical order total (item revenue + shipping_cost).
-- Money is REAL: tolerance 0.01 absorbs float representation noise.
-- Also flags delivered orders with no captured payment at all.
WITH order_totals AS (
    SELECT
        o.order_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status = 'delivered'
    GROUP BY o.order_id, o.shipping_cost
),
captured_payments AS (
    SELECT order_id, SUM(amount) AS paid_total
    FROM payments
    WHERE status = 'captured'
    GROUP BY order_id
)
SELECT
    t.order_id,
    ROUND(t.order_total, 2) AS order_total,
    ROUND(p.paid_total, 2)  AS paid_total
FROM order_totals AS t
LEFT JOIN captured_payments AS p ON p.order_id = t.order_id
WHERE p.order_id IS NULL
   OR ABS(t.order_total - p.paid_total) > 0.01;
```

```text
(zero rows returned — pass)
```

The `LEFT JOIN` + `p.order_id IS NULL` branch catches "delivered but never paid"; the `ABS(...) > 0.01` branch catches amount mismatches. The tolerance is not optional pedantry — with exact equality (`t.order_total <> p.paid_total`) the test raises false alarms on most of the table, because `REAL` arithmetic accumulates sub-cent representation error:

```sql
WITH order_totals AS (
    SELECT
        o.order_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status = 'delivered'
    GROUP BY o.order_id, o.shipping_cost
),
captured_payments AS (
    SELECT order_id, SUM(amount) AS paid_total
    FROM payments
    WHERE status = 'captured'
    GROUP BY order_id
)
SELECT COUNT(*) AS false_alarms_with_exact_equality
FROM order_totals AS t
JOIN captured_payments AS p ON p.order_id = t.order_id
WHERE t.order_total <> p.paid_total;
```

```text
╭──────────────────────────────────╮
│ false_alarms_with_exact_equality │
╞══════════════════════════════════╡
│                             2906 │
╰──────────────────────────────────╯
```

2,906 of 5,207 delivered orders "fail" under exact equality — every one of them by less than half a cent. (In PostgreSQL you'd store money as `numeric` and demand exact equality; Module 8 discussed why `REAL` money is a course simplification.)

### Exercise 7 — Current price rows are consistent

Save as `tests/test_price_history_current.sql`:

```sql
-- Test: SCD invariants on price_history.
-- (a) every active product has exactly one current row (valid_to IS NULL)
-- (b) every current row's price equals products.unit_price
SELECT
    p.product_id,
    'active product without exactly one current price row' AS problem
FROM products AS p
WHERE p.is_active = 1
  AND (SELECT COUNT(*)
       FROM price_history AS ph
       WHERE ph.product_id = p.product_id
         AND ph.valid_to IS NULL) <> 1
UNION ALL
SELECT
    ph.product_id,
    'current price_history price differs from products.unit_price'
FROM price_history AS ph
JOIN products AS p ON p.product_id = ph.product_id
WHERE ph.valid_to IS NULL
  AND ph.price <> p.unit_price;
```

```text
(zero rows returned — pass)
```

Two violation queries, one file, and the `problem` column tells you *which* invariant broke without opening the SQL. The `<> 1` in part (a) is deliberate: it catches both zero current rows (no valid price!) and two-plus current rows (ambiguous price) in one predicate. Part (b) intentionally checks *all* products with a current row, active or not — a mismatch on a discontinued product is still corrupt data.

### Exercise 8 — Events freshness

Save as `tests/test_events_freshness.sql`:

```sql
-- Test: the clickstream is fresh (newest event on/after 2026-07-01).
-- Production version, against a live pipeline:
--     HAVING MAX(occurred_at) < datetime('now', '-1 day')
-- A pinned threshold on live data rots in both directions: too tight and
-- it starts failing on quiet weekends as time passes; the rolling window
-- always measures "recent relative to today". We pin here only because
-- this course dataset is frozen at 2026-07-14.
SELECT MAX(occurred_at) AS newest_event
FROM events
HAVING MAX(occurred_at) < '2026-07-01';
```

```text
(zero rows returned — pass)
```

Same `HAVING`-without-`GROUP BY` single-row assertion as the shipped orders-freshness test: the aggregate row is emitted only when the invariant is violated, and then it carries the diagnostic (the actual stale timestamp).

## Challenge

### Exercise 9 — Four defects in the AOV query

The four correctness defects, as review comments:

1. **Join fan-out (row multiplication).** `payments` is one-to-many with `orders` — 172 returned orders carry a capture *and* a refund row, 342 carry a failed attempt plus its successful retry (506 orders in all have multiple payment rows) — so item rows are duplicated before `AVG` sees them, and `COUNT(*) AS orders` counts (item × payment) rows, not orders. Nothing from `payments` even appears in the output; the join must go. (Sweden shows "1561 orders" — it has nowhere near that; that's a line-count artifact.)
2. **Population defined by accident, part 1: no status filter.** Canonical AOV averages *non-cancelled* orders. Nothing excludes `cancelled` here — it only *happens* to work because cancelled orders have no payment rows, so the inner join drops them. Delete the (already wrong) payments join and cancelled orders silently leak in. Correctness by coincidence is a defect on its own.
3. **Population defined by accident, part 2: paying a hidden price for the join.** The same inner join silently *removes* any order with no payment row yet. In this frozen dataset 2025 gets away with it — every `pending` order sits in 2026, so all 2,030 non-cancelled 2025 orders have a payment row — but rerun the identical query for 2026 and the 32 pending orders with no payment row yet vanish from a population canonical AOV says to include. A query whose population survives only by luck of the date range is defective today, not when the luck runs out. The population must be stated in `WHERE`, not implied by joins.
4. **Wrong metric and wrong grain.** `AVG(oi.quantity * oi.unit_price)` averages raw *line* values: discounts ignored, shipping ignored, and the "average" is over items, so an order with five lines weighs five times an order with one. AOV is an average of per-order totals — you must aggregate to order grain first, then average.

(Style extras that don't count toward the four: comma joins, `ORDER BY 2`, and the sargability of `strftime('%Y', ...)` versus a half-open range — on this dataset the date filter still selects the right rows, it just can't use an index and violates the style guide.)

Corrected, per the canonical definition — two aggregation levels, orders first, countries second:

```sql
-- 2025 AOV by country.
-- Grain: one row per customer country.
-- AOV = average canonical order total (items + shipping) across
-- non-cancelled orders placed in 2025 (pending/returned included).
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
    GROUP BY o.order_id, o.customer_id, o.shipping_cost
)
SELECT
    c.country,
    ROUND(AVG(ot.order_total), 2) AS aov,
    COUNT(*)                      AS n_orders
FROM order_totals AS ot
JOIN customers    AS c ON c.customer_id = ot.customer_id
GROUP BY c.country
ORDER BY aov DESC;
```

```text
╭────────────────┬────────┬──────────╮
│    country     │  aov   │ n_orders │
╞════════════════╪════════╪══════════╡
│ Netherlands    │ 637.83 │      165 │
│ Switzerland    │ 572.56 │       94 │
│ Germany        │ 569.58 │      272 │
│ Sweden         │ 567.26 │      603 │
│ Denmark        │ 559.51 │      245 │
│ United Kingdom │  547.4 │      163 │
│ Norway         │ 535.84 │      213 │
│ Finland        │ 533.03 │      139 │
│ Austria        │ 520.83 │       44 │
│ France         │ 516.57 │       92 │
╰────────────────┴────────┴──────────╯
```

Prediction check: correct AOVs are **much higher** (Netherlands 262.38 → 637.83). Averaging per *line* is dominated by the many small lines inside big orders; summing to order grain first restores the multi-item orders that make AOV what it is. Order counts collapse from payment-inflated line counts to the truth (Sweden 1561 → 603), and the ranking reshuffles — Switzerland jumps from 6th to 2nd. Every number *and* the story changed: this is why grain defects are the dangerous kind.

### Exercise 10 — Break the database, watch the suite catch it

Work on a copy — never on `shop.db`:

```bash
cp shop.db /tmp/broken.db
sqlite3 /tmp/broken.db "
UPDATE addresses
SET is_default = 1
WHERE address_id = (SELECT MIN(address_id) FROM addresses WHERE is_default = 0);"
bash tests/run_tests.sh /tmp/broken.db; echo "exit code: $?"
```

```text
FAIL  tests/test_addresses_one_default.sql  (1 violating rows)
╭─────────────┬────────────╮
│ customer_id │ n_defaults │
╞═════════════╪════════════╡
│           3 │          2 │
╰─────────────┴────────────╯
PASS  tests/test_customers_email_unique.sql
PASS  tests/test_order_items_grain.sql
PASS  tests/test_orders_freshness.sql
PASS  tests/test_orders_status_values.sql
PASS  tests/test_orders_valid_customer.sql
exit code: 1
```

All three confirmations in one run: (a) exactly `test_addresses_one_default` fails while the other five stay green; (b) the printed violation identifies the damage — customer 3 now has two default addresses, which is precisely the row the `UPDATE` promoted; (c) the runner exits `1`, so anything scheduling this script (cron, CI, an orchestrator) would halt the pipeline. Why the drill belongs in real projects: a test that has never been seen to fail might be vacuous — asserting nothing, querying the wrong table, or swallowed by the runner — and deliberately injecting a known defect is the only cheap proof that the alarm is actually wired to anything. Clean up with `rm /tmp/broken.db` if you like; nothing touched `shop.db`.
