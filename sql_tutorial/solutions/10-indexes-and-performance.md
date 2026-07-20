# Module 10 Solutions — Indexes & Performance

All solutions run against `scratch.db` in its **end-of-module state** (amplified tables, the four final indexes — `idx_big_orders_cust_date_status`, `idx_big_orders_ordered_at`, `idx_big_orders_pending`, `idx_big_order_items_product` — and fresh `ANALYZE` statistics). Solve **in order**: indexes created by earlier solutions (5, 7, 8) stay in place and are assumed by later plan outputs. Timings are from one representative run; yours will differ by a few milliseconds — the *ratios* and the *plans* are what must reproduce.

## Warm-up

### Exercise 1 — predict SCAN or SEARCH

Predictions: (a) SEARCH — `order_id` is the `INTEGER PRIMARY KEY`, i.e. the table's own B-tree; (b) SCAN — no index involves `shipping_cost`; (c) SEARCH — equality on `customer_id` + range on `ordered_at` is exactly the leftmost prefix of `idx_big_orders_cust_date_status`.

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE order_id = 300000;
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE shipping_cost = 0;
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 105 AND ordered_at >= '2026-03-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING INTEGER PRIMARY KEY (rowid=?)
QUERY PLAN
`--SCAN big_orders
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date_status (customer_id=? AND ordered_at>?)
```

All three as predicted. Note (c)'s parenthesis: both the equality and the range participate in the seek.

### Exercise 2 — is an index on customers(country) worth it?

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS swedish_customers FROM customers WHERE country = 'Sweden';"
```
```text
╭───────────────────╮
│ swedish_customers │
╞═══════════════════╡
│               175 │
╰───────────────────╯
Run Time: real 0.000364 user 0.000000 sys 0.000367
```

**No.** The full scan of 800 rows already runs in ~0.4 ms — the table fits in a few pages, so an index can save at most fractions of a millisecond while permanently taxing every customer insert/update and occupying space. Additionally, `country = 'Sweden'` matches 175/800 ≈ 22% of rows — poor selectivity, so even on a bigger table this particular index would be marginal (§10.3 + §10.5). Revisit only if `customers` grows by orders of magnitude *and* country filters stay selective.

### Exercise 3 — leftmost-prefix predictions for `idx_big_orders_cust_date_status`

Predictions: (a) SEARCH (prefix `customer_id`); (b) SEARCH (prefix + trailing range); (c) SCAN — `ordered_at` alone is not a leftmost prefix... but see below; (d) SEARCH on `customer_id` only — `status` sits *behind* the `ordered_at` position, so it cannot narrow the seek.

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682;
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682 AND ordered_at >= '2026-01-01';
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE ordered_at >= '2026-01-01';
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682 AND status = 'delivered';
```
```text
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date_status (customer_id=?)
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date_status (customer_id=? AND ordered_at>?)
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_ordered_at (ordered_at>?)
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date_status (customer_id=?)
```

(a), (b), (d) as predicted. (c) is a small trap: the *composite* index indeed can't serve it — but the module also built the single-column `idx_big_orders_ordered_at`, and the optimizer used that. The leftmost-prefix reasoning was still correct; always remember the planner chooses among **all** available indexes. For (d), the seek narrows only by `customer_id` (`status` behind the unconstrained `ordered_at` is unusable for seeking); the engine still checks `status = 'delivered'` on each of the customer's entries — it just reads them all first.

## Core

### Exercise 4 — Q1-2024 gross revenue: sargable rewrite

Diagnose the original:

```sql
-- BAD: strftime() on the filter column forces a full scan
EXPLAIN QUERY PLAN
SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
WHERE strftime('%Y', o.ordered_at) = '2024'
  AND strftime('%m', o.ordered_at) IN ('01', '02', '03')
  AND o.status <> 'cancelled';
```
```text
QUERY PLAN
|--SCAN o
`--SEARCH oi USING INDEX sqlite_autoindex_big_order_items_1 (order_id=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
WHERE strftime('%Y', o.ordered_at) = '2024'
  AND strftime('%m', o.ordered_at) IN ('01', '02', '03')
  AND o.status <> 'cancelled';"
```
```text
╭───────────────╮
│ gross_revenue │
╞═══════════════╡
│    7514834.82 │
╰───────────────╯
Run Time: real 0.200965 user 0.172390 sys 0.028097
```

`SCAN o`: the functions on `ordered_at` hide the date from `idx_big_orders_ordered_at`, so all 768,000 orders are read and `strftime` runs twice per row. Q1 2024 is one contiguous half-open range — Pitfall 1's fix applies directly:

```sql
EXPLAIN QUERY PLAN
SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
WHERE o.ordered_at >= '2024-01-01' AND o.ordered_at < '2024-04-01'
  AND o.status <> 'cancelled';
```
```text
QUERY PLAN
|--SEARCH o USING INDEX idx_big_orders_ordered_at (ordered_at>? AND ordered_at<?)
`--SEARCH oi USING INDEX sqlite_autoindex_big_order_items_1 (order_id=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
WHERE o.ordered_at >= '2024-01-01' AND o.ordered_at < '2024-04-01'
  AND o.status <> 'cancelled';"
```
```text
╭───────────────╮
│ gross_revenue │
╞═══════════════╡
│    7514834.82 │
╰───────────────╯
Run Time: real 0.051441 user 0.019186 sys 0.032051
```

Identical revenue, 201 ms → 51 ms (4×): the driver became a seek into just the Q1 slice, and only those orders' line items get probed. **Common wrong approach:** creating an expression index on `strftime('%Y', ordered_at)` (or on `'%Y-%m'`). It would serve only queries with that exact expression — the next question ("Q1 vs Q2", "last 90 days") is back to a scan, and you'd pay for a second index the plain `ordered_at` index makes unnecessary (§10.9).

### Exercise 5 — Innsbruck deliveries: index the FK you join on

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) AS delivered_to_innsbruck
FROM addresses AS a
JOIN big_orders AS o ON o.address_id = a.address_id
WHERE a.city = 'Innsbruck' AND o.status = 'delivered';
```
```text
QUERY PLAN
|--SCAN o
|--BLOOM FILTER ON a (address_id=?)
`--SEARCH a USING INTEGER PRIMARY KEY (rowid=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS delivered_to_innsbruck
FROM addresses AS a
JOIN big_orders AS o ON o.address_id = a.address_id
WHERE a.city = 'Innsbruck' AND o.status = 'delivered';"
```
```text
╭────────────────────────╮
│ delivered_to_innsbruck │
╞════════════════════════╡
│                   5760 │
╰────────────────────────╯
Run Time: real 0.042558 user 0.033277 sys 0.009175
```

Only 11 addresses are in Innsbruck, but SQLite cannot get *from those addresses into `big_orders`* — `big_orders.address_id` has no index — so it runs the join backwards: scan all 768,000 orders and probe `addresses` for each. The fix is the child-side FK index (§10.12):

```bash
sqlite3 -box scratch.db ".timer on" "CREATE INDEX idx_big_orders_address ON big_orders (address_id);"
```
```text
Run Time: real 0.204043 user 0.183507 sys 0.020127
```

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) AS delivered_to_innsbruck
FROM addresses AS a
JOIN big_orders AS o ON o.address_id = a.address_id
WHERE a.city = 'Innsbruck' AND o.status = 'delivered';
```
```text
QUERY PLAN
|--SCAN a
`--SEARCH o USING INDEX idx_big_orders_address (address_id=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS delivered_to_innsbruck
FROM addresses AS a
JOIN big_orders AS o ON o.address_id = a.address_id
WHERE a.city = 'Innsbruck' AND o.status = 'delivered';"
```
```text
╭────────────────────────╮
│ delivered_to_innsbruck │
╞════════════════════════╡
│                   5760 │
╰────────────────────────╯
Run Time: real 0.008076 user 0.003071 sys 0.004937
```

The plan flipped to drive from the 1,114-row `addresses` table (a harmless scan) with seeks into orders: 43 ms → 8 ms, and unlike the original, the cost now tracks *Innsbruck's* order volume rather than Nordkart's total. **Common wrong approach:** indexing `addresses(city)` — it targets the side that was already cheap (1,114 rows) and leaves the 768,000-row scan in place.

### Exercise 6 — daily order counts for June 2026

```sql
-- BAD: date() on the column, and an inclusive BETWEEN on top
EXPLAIN QUERY PLAN
SELECT date(ordered_at) AS day, COUNT(*) AS orders
FROM big_orders
WHERE date(ordered_at) BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY day;
```
```text
QUERY PLAN
|--SCAN big_orders USING COVERING INDEX idx_big_orders_ordered_at
`--USE TEMP B-TREE FOR GROUP BY
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT date(ordered_at) AS day, COUNT(*) AS orders
FROM big_orders
WHERE date(ordered_at) BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY day
LIMIT 3;"
```
```text
╭────────────┬────────╮
│    day     │ orders │
╞════════════╪════════╡
│ 2026-06-01 │   2176 │
│ 2026-06-02 │   3456 │
│ 2026-06-03 │   2432 │
╰────────────┴────────╯
Run Time: real 0.083660 user 0.071461 sys 0.011975
```

A SCAN (of the whole index — the verb is what counts), running `date()` on all 768,000 entries. Move the function out of WHERE; it may absolutely stay in SELECT/GROUP BY, because there it runs only on the rows that *survive* the filter:

```sql
SELECT date(ordered_at) AS day, COUNT(*) AS orders
FROM big_orders
WHERE ordered_at >= '2026-06-01' AND ordered_at < '2026-07-01'
GROUP BY day;
```

Plan and timing:

```sql
EXPLAIN QUERY PLAN
SELECT date(ordered_at) AS day, COUNT(*) AS orders
FROM big_orders
WHERE ordered_at >= '2026-06-01' AND ordered_at < '2026-07-01'
GROUP BY day;
```
```text
QUERY PLAN
|--SEARCH big_orders USING COVERING INDEX idx_big_orders_ordered_at (ordered_at>? AND ordered_at<?)
`--USE TEMP B-TREE FOR GROUP BY
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT date(ordered_at) AS day, COUNT(*) AS orders
FROM big_orders
WHERE ordered_at >= '2026-06-01' AND ordered_at < '2026-07-01'
GROUP BY day
LIMIT 3;"
```
```text
╭────────────┬────────╮
│    day     │ orders │
╞════════════╪════════╡
│ 2026-06-01 │   2176 │
│ 2026-06-02 │   3456 │
│ 2026-06-03 │   2432 │
╰────────────┴────────╯
Run Time: real 0.015467 user 0.014334 sys 0.001040
```

84 ms → 15 ms. Two separate defects were fixed: the non-sargable `date()` in WHERE (performance), and the `BETWEEN ... '2026-06-30'` pattern — here it happened to work only because `date()` had already truncated the timestamps; against the raw column it would silently drop almost all of June 30 (Module 2's half-open-range rule is about *correctness* first).

### Exercise 7 — the returned-orders queue: partial index

```sql
EXPLAIN QUERY PLAN
SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'returned'
ORDER BY ordered_at DESC
LIMIT 10;
```
```text
QUERY PLAN
`--SCAN big_orders USING INDEX idx_big_orders_ordered_at
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'returned'
ORDER BY ordered_at DESC
LIMIT 3;"
```
```text
╭──────────┬─────────────┬─────────────────────╮
│ order_id │ customer_id │     ordered_at      │
╞══════════╪═════════════╪═════════════════════╡
│     4253 │         503 │ 2026-06-20 12:20:13 │
│    10253 │         503 │ 2026-06-20 12:20:13 │
│    16253 │         503 │ 2026-06-20 12:20:13 │
╰──────────┴─────────────┴─────────────────────╯
Run Time: real 0.033744 user 0.022544 sys 0.011123
```

The optimizer walks the date index backwards (avoiding a sort) but must probe row after row until it has found 10 with `status = 'returned'` — ~3% of rows, so tens of thousands of probes. A polled query deserves the §10.10 treatment — an index containing *only* returned orders, pre-sorted by date:

```sql
CREATE INDEX idx_big_orders_returned ON big_orders (ordered_at) WHERE status = 'returned';
EXPLAIN QUERY PLAN
SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'returned'
ORDER BY ordered_at DESC
LIMIT 10;
```
```text
QUERY PLAN
`--SCAN big_orders USING INDEX idx_big_orders_returned
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'returned'
ORDER BY ordered_at DESC
LIMIT 3;"
```
```text
╭──────────┬─────────────┬─────────────────────╮
│ order_id │ customer_id │     ordered_at      │
╞══════════╪═════════════╪═════════════════════╡
│   766253 │         503 │ 2026-06-20 12:20:13 │
│   760253 │         503 │ 2026-06-20 12:20:13 │
│   754253 │         503 │ 2026-06-20 12:20:13 │
╰──────────┴─────────────┴─────────────────────╯
Run Time: real 0.000327 user 0.000000 sys 0.000324
```

34 ms → 0.3 ms — a 100× win for ~600 KiB (every row in this index matches, so the backward walk stops after LIMIT entries; the same timestamps appear under different `order_id`s because the amplified copies tie, which is fine). **Why not a plain `status` index?** §10.5/§10.10 showed it: it would index all 768,000 rows (13 MiB) to serve queries about the ~3%, its entries aren't ordered by date within a status (so `ORDER BY ... LIMIT` still needs extra work), and on builds without `sqlite_stat4` the planner may distrust it entirely.

### Exercise 8 — discount audit: covering composite

```sql
EXPLAIN QUERY PLAN
SELECT discount_pct, SUM(quantity) AS units
FROM big_order_items
WHERE discount_pct >= 15
GROUP BY discount_pct;
```
```text
QUERY PLAN
|--SCAN big_order_items
`--USE TEMP B-TREE FOR GROUP BY
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT discount_pct, SUM(quantity) AS units
FROM big_order_items
WHERE discount_pct >= 15
GROUP BY discount_pct;"
```
```text
╭──────────────┬────────╮
│ discount_pct │ units  │
╞══════════════╪════════╡
│           15 │ 100736 │
│           20 │  45184 │
╰──────────────┴────────╯
Run Time: real 0.063148 user 0.052244 sys 0.010768
```

The query touches exactly two columns: `discount_pct` (filter + group) and `quantity` (aggregate). Put both in one index — filter column first so the range predicate seeks, aggregated column second purely as payload:

```sql
CREATE INDEX idx_big_order_items_discount ON big_order_items (discount_pct, quantity);
EXPLAIN QUERY PLAN
SELECT discount_pct, SUM(quantity) AS units
FROM big_order_items
WHERE discount_pct >= 15
GROUP BY discount_pct;
```
```text
QUERY PLAN
`--SEARCH big_order_items USING COVERING INDEX idx_big_order_items_discount (discount_pct>?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT discount_pct, SUM(quantity) AS units
FROM big_order_items
WHERE discount_pct >= 15
GROUP BY discount_pct;"
```
```text
╭──────────────┬────────╮
│ discount_pct │ units  │
╞══════════════╪════════╡
│           15 │ 100736 │
│           20 │  45184 │
╰──────────────┴────────╯
Run Time: real 0.005351 user 0.004998 sys 0.000347
```

63 ms → 5 ms. The "never touches the table" proof is right in the plan: **`SEARCH ... USING COVERING INDEX`** — seek to `discount_pct = 15`, read forward through the ~121k qualifying entries (already grouped, since the index is sorted by `discount_pct`), and the table's 1.7M rows are never opened. An index on `discount_pct` alone would seek but then hop to the table 121,000 times for `quantity` — measurably worse and barely smaller.

### Exercise 9 — `LIKE '2025-12%'` on an indexed column

```sql
-- BAD: LIKE on an indexed TEXT column still cannot seek (collation mismatch)
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE ordered_at LIKE '2025-12%';
```
```text
QUERY PLAN
`--SCAN big_orders USING COVERING INDEX idx_big_orders_ordered_at
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS december_orders FROM big_orders WHERE ordered_at LIKE '2025-12%';"
```
```text
╭─────────────────╮
│ december_orders │
╞═════════════════╡
│           57216 │
╰─────────────────╯
Run Time: real 0.031535 user 0.028844 sys 0.002604
```

The two reasons the analyst is wrong: (1) `LIKE` is a *pattern* operator, not a range — the engine may rewrite a prefix pattern into a range only under the LIKE-optimization's conditions, and (2) those conditions fail here: default `LIKE` is case-insensitive, while `idx_big_orders_ordered_at` is a plain (binary-collation) index, so the rewrite is unsound in general (`'2025-12x'` vs `'2025-12X'`) and SQLite refuses it. Since digits have no case, the human fix is to say what is meant — a range:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE ordered_at >= '2025-12-01' AND ordered_at < '2026-01-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date_status (ANY(customer_id) AND ordered_at>? AND ordered_at<?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS december_orders FROM big_orders
WHERE ordered_at >= '2025-12-01' AND ordered_at < '2026-01-01';"
```
```text
╭─────────────────╮
│ december_orders │
╞═════════════════╡
│           57216 │
╰─────────────────╯
Run Time: real 0.003737 user 0.003727 sys 0.000000
```

Same 57,216 orders, 31 ms → 4 ms. The plan holds a bonus lesson: with fresh statistics the optimizer chose a **skip-scan** of the composite index (`ANY(customer_id)` = "for each customer, range-scan their December slice") over the plain date index — both are SEARCHes, and the planner is free to pick either; what matters is that the predicate became seekable at all. (In the module's pre-`ANALYZE` state the same rewrite used `idx_big_orders_ordered_at` directly.)

## Challenge

### Exercise 10 — minimal index set for the described workload

The design (starting from bare amplified tables):

| # | Pattern | Index | Reasoning |
|---|---|---|---|
| a | order by id + its lines | **none needed** | `big_orders.order_id` is the `INTEGER PRIMARY KEY`; the lines are reached via `big_order_items`'s PK `(order_id, product_id)` — `order_id` is its leftmost prefix. |
| b | customer history, newest first | `CREATE INDEX idx_big_orders_cust_date ON big_orders (customer_id, ordered_at);` | Equality column first, sort column second: seek to the customer, read their slice already date-ordered (backwards for `DESC`). Also serves any `customer_id`-only query via the prefix rule. |
| c | pending queue, oldest first | `CREATE INDEX idx_big_orders_pending ON big_orders (ordered_at) WHERE status = 'pending';` | Hot, tiny, skewed subset: a partial index is ~1% the size of a full `status` index, comes out pre-sorted, and shrinks as orders leave `pending`. |
| d | revenue for arbitrary date range | `CREATE INDEX idx_big_orders_ordered_at ON big_orders (ordered_at);` | One raw-column range index answers *every* period (day/month/quarter); line items are then reached through `big_order_items`'s PK. Expression indexes per calendar grain would be rigid and redundant. |
| e | units sold per product | `CREATE INDEX idx_big_order_items_product ON big_order_items (product_id);` | The child-side FK join column; `product_id` is *not* a leftmost prefix of the PK `(order_id, product_id)`, so it needs its own index. Appending `quantity` to make it covering is a defensible upgrade if (e) is hot. |
| f | nightly bulk load | **no index — a constraint on the others** | Four secondary B-trees across two tables is the write-amplification budget; §10.11 measured ~1.8× insert cost at three indexes on `big_orders`. Anything more must buy a named query. |

Deliberately **not** indexed: `status` alone (low selectivity, §10.5), `shipping_cost`/`address_id`/`discount_pct` (no pattern in this workload asks), and no expression indexes. This is, not coincidentally, essentially the module's final index set (the module's `..._cust_date_status` variant just adds `status` as covering payload for pattern (b) — a judgment call trading index width for zero table hops). Verification that each pattern seeks, using the existing state:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE order_id = 5;
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682 ORDER BY ordered_at DESC;
EXPLAIN QUERY PLAN
SELECT order_id, ordered_at FROM big_orders WHERE status = 'pending' ORDER BY ordered_at;
EXPLAIN QUERY PLAN
SELECT date(ordered_at) AS day, COUNT(*) FROM big_orders
WHERE ordered_at >= '2026-06-01' AND ordered_at < '2026-07-01' GROUP BY day;
EXPLAIN QUERY PLAN
SELECT SUM(quantity) FROM big_order_items WHERE product_id = 55;
```
```text
QUERY PLAN
`--SEARCH big_orders USING INTEGER PRIMARY KEY (rowid=?)
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date_status (customer_id=?)
QUERY PLAN
`--SCAN big_orders USING COVERING INDEX idx_big_orders_pending
QUERY PLAN
|--SEARCH big_orders USING COVERING INDEX idx_big_orders_ordered_at (ordered_at>? AND ordered_at<?)
`--USE TEMP B-TREE FOR GROUP BY
QUERY PLAN
`--SEARCH big_order_items USING INDEX idx_big_order_items_product (product_id=?)
```

Pattern (c)'s line is the "justified scan": scanning the 8k-entry partial index *is* the optimal plan. Note also (b): no sort step appears — the index delivers the customer's rows in date order.

### Exercise 11 — predict the chosen index

Predictions: (a) `idx_big_orders_cust_date_status`, COVERING — the query touches `customer_id` and `status`, both in the index, seek on `customer_id`; grouping by `status` (out of index order) will need a temp B-tree. (b) `idx_big_orders_pending`, COVERING — the WHERE clause proves `status = 'pending'`, and the partial index's key is exactly `ordered_at`, so the date filter *seeks*; `COUNT(*)` needs no other column. (c) no seek possible — the module *dropped* `idx_big_orders_month`, and no index matches the expression: expect a SCAN (over some covering index, since only `ordered_at` is referenced).

```sql
EXPLAIN QUERY PLAN
SELECT status, COUNT(*) FROM big_orders WHERE customer_id = 682 GROUP BY status;
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE status = 'pending' AND ordered_at >= '2026-06-01';
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';
```
```text
QUERY PLAN
|--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date_status (customer_id=?)
`--USE TEMP B-TREE FOR GROUP BY
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_pending (ordered_at>?)
QUERY PLAN
`--SCAN big_orders USING COVERING INDEX idx_big_orders_ordered_at
```

All three as predicted. (b) is the elegant one — a partial index used both for its *implied predicate* (`status = 'pending'`) and a *seek on its key* (`ordered_at>?`), reading a few thousand entries total. (c) is the cautionary one: the column being "indexed twice over" doesn't help a query whose predicate isn't phrased in terms the B-tree understands — 768,000 entries read, `strftime` evaluated on every one.
