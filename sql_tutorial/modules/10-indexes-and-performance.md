# Module 10 — Indexes & Performance

Every query you have written so far ran in milliseconds because Nordkart's database is small. Production tables are not: an events table with a hundred million rows will happily let you write a query that takes twenty minutes instead of twenty milliseconds, and nothing in the SQL syntax warns you. The difference is almost always whether the engine can *seek* to the rows you want or has to *read everything and check*. This module teaches you to see which of the two is happening (`EXPLAIN QUERY PLAN`), to fix it (the right index, or a rewrite that lets an existing index work), and — just as important — to know when an index is a waste of space and write throughput.

We use SQLite as the lab, but B-trees, composite keys, covering/partial/expression indexes, selectivity, and sargability work the same way in PostgreSQL, MySQL, and every serious warehouse-adjacent engine. The plans look different; the reasoning transfers.

## What you'll learn

- What a B-tree index physically is, and why it gives O(log n) point lookups *and* cheap range scans
- The rowid B-tree every SQLite table already has, and why `INTEGER PRIMARY KEY` lookups are free
- Reading `EXPLAIN QUERY PLAN`: `SCAN` vs `SEARCH`, `USING INDEX` vs `USING COVERING INDEX`
- A measurement workflow with `.timer on` and `.eqp on`
- Creating indexes and proving they help — before/after plans and timings, not vibes
- Selectivity: why an index on `customer_id` pays off and an index on `status` mostly doesn't
- `ANALYZE` and `sqlite_stat1`: how the optimizer learns your data's shape
- Composite indexes and the leftmost-prefix rule
- Covering, expression, and partial indexes — and what each one costs
- Indexing the foreign keys you join on
- Sargability: rewriting predicates (`date()` wrappers, leading-wildcard `LIKE`, `OR`) so indexes can work
- When a full scan is genuinely the right plan, and when the optimizer ignores your index on purpose

## 10.1 Setup: a disposable, amplified copy

**Do not experiment on `shop.db`.** Index work means DDL, and this module also deliberately builds *bad* indexes. Work on a copy. From the course root:

```bash
cp shop.db scratch.db
```
```text
(no output)
```

**Every `sql` block from here to the end of this module runs against `scratch.db`**, e.g. by starting the shell with `sqlite3 -box scratch.db` (the `-box` flag gives the table-style output shown throughout the course).

There is a second problem: 6,000 orders is too small to feel anything — every plan, good or bad, finishes in single-digit milliseconds. So we build amplified copies of `orders` and `order_items` with 128× the rows, using a recursive CTE (Module 5) to stamp out 127 extra copies with shifted `order_id`s (original ids run 1–6000, so copy *n* gets ids `n*6000 + 1 … n*6000 + 6000`, and order lines keep pointing at their order):

```sql
CREATE TABLE big_orders (
  order_id      INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL,
  address_id    INTEGER NOT NULL,
  status        TEXT NOT NULL,
  shipping_cost REAL NOT NULL,
  ordered_at    TEXT NOT NULL
);

INSERT INTO big_orders
SELECT * FROM orders;

WITH RECURSIVE copies(n) AS (
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM copies WHERE n < 127
)
INSERT INTO big_orders
SELECT o.order_id + c.n * 6000,
       o.customer_id, o.address_id, o.status, o.shipping_cost, o.ordered_at
FROM orders AS o
CROSS JOIN copies AS c;

CREATE TABLE big_order_items (
  order_id     INTEGER NOT NULL,
  product_id   INTEGER NOT NULL,
  quantity     INTEGER NOT NULL,
  unit_price   REAL NOT NULL,
  discount_pct INTEGER NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

INSERT INTO big_order_items
SELECT * FROM order_items;

WITH RECURSIVE copies(n) AS (
  SELECT 1
  UNION ALL
  SELECT n + 1 FROM copies WHERE n < 127
)
INSERT INTO big_order_items
SELECT oi.order_id + c.n * 6000,
       oi.product_id, oi.quantity, oi.unit_price, oi.discount_pct
FROM order_items AS oi
CROSS JOIN copies AS c;

SELECT (SELECT COUNT(*) FROM big_orders)      AS big_orders_rows,
       (SELECT COUNT(*) FROM big_order_items) AS big_order_items_rows;
```
```text
╭─────────────────┬──────────────────────╮
│ big_orders_rows │ big_order_items_rows │
╞═════════════════╪══════════════════════╡
│          768000 │              1724800 │
╰─────────────────┴──────────────────────╯
```

768,000 orders and 1.7 million order lines — enough to make bad plans visibly slow. Keep in mind the data is duplicated 128×: business numbers computed on `big_orders` are inflated 128-fold and timestamps repeat. That's fine; this copy is a performance lab, not a reporting source.

## 10.2 What an index physically is

A table without any help is just pages of rows in no useful order. To find "orders of customer 682" the engine must read every page and check every row — a **full scan**, O(n), and n is what grows on you in production.

A **B-tree index** is a separate, *sorted* structure: the indexed values, each carrying a pointer to its row (in SQLite, the row's `rowid`). "B-tree" just means the sorted values are stored in a shallow tree of pages: a root page whose entries say "values up to F are in that child, up to M in that one, …", one or two levels of the same, then leaf pages holding the actual entries. Two properties fall out of "sorted + shallow":

1. **Point lookups are O(log n).** Finding one value means walking root → child → leaf: 3–4 page reads even for millions of rows, instead of thousands.
2. **Range scans are cheap.** Because leaves are sorted, `BETWEEN`, `>=`, `< `, and `ORDER BY` on the indexed column mean: seek to the start, then read leaf entries in order until you pass the end. No sorting, no full pass.

That is the whole mental model. A phone book is a B-tree on `(last_name, first_name)`: you can find "Nilsson" in seconds (seek), you can read all Nilssons consecutively (range scan), and you absolutely cannot use it to find everyone whose *first* name is Astrid (wrong sort order — remember this for §10.7).

### The index you already have: rowid and INTEGER PRIMARY KEY

In SQLite every ordinary table *is* a B-tree, keyed by a hidden 64-bit `rowid`. When you declare a column `INTEGER PRIMARY KEY` — as `big_orders.order_id` is — that column becomes an alias for the rowid. So primary-key lookups need no extra index; the table itself is the index:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE order_id = 424242;
```
```text
QUERY PLAN
`--SEARCH big_orders USING INTEGER PRIMARY KEY (rowid=?)
```

`EXPLAIN QUERY PLAN` (from here on: EQP) prefixed to any query prints how SQLite will execute it without running it. The two verbs that matter:

- **`SEARCH`** — the engine seeks directly to matching rows via a B-tree. O(log n). Good.
- **`SCAN`** — the engine reads the whole thing and filters. O(n). Fine for small tables, deadly for big ones.

Turn on the timer and run it for real:

```bash
sqlite3 -box scratch.db ".timer on" "SELECT * FROM big_orders WHERE order_id = 424242;"
```
```text
╭──────────┬─────────────┬────────────┬───────────┬───────────────┬─────────────────────╮
│ order_id │ customer_id │ address_id │  status   │ shipping_cost │     ordered_at      │
╞══════════╪═════════════╪════════════╪═══════════╪═══════════════╪═════════════════════╡
│   424242 │         718 │       1003 │ delivered │           4.9 │ 2026-03-07 19:11:58 │
╰──────────┴─────────────┴────────────┴───────────┴───────────────┴─────────────────────╯
Run Time: real 0.000263 user 0.000261 sys 0.000000
```

0.26 ms to find one row in 768,000. Now the same table, but filtering on a column with no index — say support wants customer 682's order history:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682;
```
```text
QUERY PLAN
`--SCAN big_orders
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_placed FROM big_orders WHERE customer_id = 682;"
```
```text
╭───────────────╮
│ orders_placed │
╞═══════════════╡
│          6400 │
╰───────────────╯
Run Time: real 0.029282 user 0.015983 sys 0.013184
```

29 ms — a hundred times slower than the PK lookup, because SQLite examined all 768,000 rows to find the 6,400 that match. On this table that's an annoyance; on a billion-row table the same shape of query is an outage.

### The workflow: `.eqp on` + `.timer on`

Inside the `sqlite3` shell you don't type `EXPLAIN QUERY PLAN` by hand all day. Set two dot-commands once per session and every query prints its plan and its wall-clock time:

```bash
sqlite3 -box scratch.db ".eqp on" ".timer on" "SELECT COUNT(*) AS orders_placed FROM big_orders WHERE customer_id = 682;"
```
```text
QUERY PLAN
`--SCAN big_orders
╭───────────────╮
│ orders_placed │
╞═══════════════╡
│          6400 │
╰───────────────╯
Run Time: real 0.028211 user 0.019004 sys 0.009107
```

That is the whole diagnostic loop of this module: **plan, time, change one thing, plan, time again.** Make it a reflex.

> **PostgreSQL note:** Postgres tables are heaps, not rowid B-trees — a declared PRIMARY KEY is backed by a real (automatically created) index. The tools are `EXPLAIN` (plan only) and `EXPLAIN ANALYZE` (plan + actually run it with per-node timings and row counts), plus `\timing` in psql. Plans are richer — Seq Scan, Index Scan, Index Only Scan, Bitmap Heap Scan — but map onto the same SCAN/SEARCH intuition.

## 10.3 When a full scan is fine

Before you index anything, know when `SCAN` is the *correct* answer.

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS swedish_customers FROM customers WHERE country = 'Sweden';"
```
```text
╭───────────────────╮
│ swedish_customers │
╞═══════════════════╡
│               175 │
╰───────────────────╯
Run Time: real 0.000431 user 0.000217 sys 0.000218
```

A full scan of all 800 customers takes 0.4 ms. `customers`, `products`, `categories`, `suppliers` — the small dimension tables — fit in a handful of pages; an index on them buys microseconds and costs maintenance. Two rules of thumb:

- **Small table → scan is fine.** If the whole table is a few hundred pages, reading it sequentially is as fast as anything.
- **Most-of-the-table reads → scan is fine even on big tables.** If a predicate matches, say, 87% of rows (foreshadowing: `status = 'delivered'`), jumping index → row → index → row for nearly every row is *slower* than one sequential pass. We'll measure exactly this in §10.5.

Indexes earn their keep when a query needs a *small fraction* of a *large table*.

## 10.4 Your first index: measure before and after

Customer order history is a real, hot query pattern (every "My orders" page hit). Index the column we filter on:

```bash
sqlite3 -box scratch.db ".timer on" "CREATE INDEX idx_big_orders_customer ON big_orders (customer_id);"
```
```text
Run Time: real 0.199837 user 0.180509 sys 0.018970
```

Naming convention used in this course: `idx_<table>_<columns>`. Building the index cost 0.2 s once — SQLite read the table, sorted 768,000 `(customer_id, rowid)` pairs, and wrote them as a new B-tree. Now:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682;
```
```text
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_customer (customer_id=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_placed FROM big_orders WHERE customer_id = 682;"
```
```text
╭───────────────╮
│ orders_placed │
╞═══════════════╡
│          6400 │
╰───────────────╯
Run Time: real 0.000382 user 0.000193 sys 0.000192
```

29 ms → 0.4 ms, a ~75× speedup from one statement. Mechanically: seek to `customer_id = 682` in the index (O(log n)), read its 6,400 consecutive entries, and for each one follow the stored rowid into the table. That last step — the per-row hop from index to table — is why the *fraction of rows matched* matters so much, as you're about to see.

## 10.5 Selectivity: not every column deserves an index

`customer_id` has 675 distinct values in `big_orders` (125 of the 800 customers have never ordered), so one value ≈ 0.15% of the table — an index seek skips 99.85% of the work. That's a **selective** predicate. Now try the same trick on `status`, where 87% of orders are `'delivered'`:

```bash
sqlite3 -box scratch.db ".timer on" "CREATE INDEX idx_big_orders_status ON big_orders (status);"
```
```text
Run Time: real 0.179764 user 0.152196 sys 0.027027
```

```sql
EXPLAIN QUERY PLAN
SELECT SUM(shipping_cost) FROM big_orders WHERE status = 'delivered';
```
```text
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_status (status=?)
```

A `SEARCH` — looks like a win. Time it, then time the same query with the index forcibly disabled (`NOT INDEXED` is a SQLite diagnostic clause — handy in exactly this situation):

```bash
sqlite3 -box scratch.db ".timer on" "SELECT ROUND(SUM(shipping_cost), 2) AS shipping_revenue FROM big_orders WHERE status = 'delivered';"
```
```text
╭──────────────────╮
│ shipping_revenue │
╞══════════════════╡
│        3809587.2 │
╰──────────────────╯
Run Time: real 0.071265 user 0.054896 sys 0.016100
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT ROUND(SUM(shipping_cost), 2) AS shipping_revenue FROM big_orders NOT INDEXED WHERE status = 'delivered';"
```
```text
╭──────────────────╮
│ shipping_revenue │
╞══════════════════╡
│        3809587.2 │
╰──────────────────╯
Run Time: real 0.044774 user 0.039647 sys 0.004998
```

The index made the query **slower**: 71 ms with, 45 ms without. For 666,000 matching rows the engine did 666,000 index-entry-to-table-row hops in whatever order the index dictated, versus one straight sequential read. This is the single most misunderstood fact about indexes: **an index on a low-selectivity predicate is worse than no index.**

So why did the optimizer pick it? Because it didn't know any better — yet.

## 10.6 ANALYZE: teaching the optimizer your data's shape

The query planner chooses between plans using *estimates* of how many rows each step will touch. Without statistics, SQLite assumes an equality on an indexed column is selective. `ANALYZE` fixes that by sampling every table and index and storing the results:

```bash
sqlite3 -box scratch.db ".timer on" "ANALYZE;"
```
```text
Run Time: real 0.202200 user 0.179680 sys 0.022210
```

```sql
SELECT * FROM sqlite_stat1 WHERE tbl LIKE 'big_%' ORDER BY idx;
```
```text
╭─────────────────┬────────────────────────────────────┬───────────────╮
│       tbl       │                idx                 │     stat      │
╞═════════════════╪════════════════════════════════════╪═══════════════╡
│ big_orders      │ idx_big_orders_customer            │ 768000 1138   │
│ big_orders      │ idx_big_orders_status              │ 768000 128000 │
│ big_order_items │ sqlite_autoindex_big_order_items_1 │ 1724800 3 1   │
╰─────────────────┴────────────────────────────────────┴───────────────╯
```

Read `stat` as "table rows, then average rows per distinct value of the first index column (then first two, …)". The optimizer now knows: one `customer_id` ≈ 1,138 rows (worth seeking), one `status` ≈ 128,000 rows (usually not). Watch it change its mind:

```sql
EXPLAIN QUERY PLAN
SELECT SUM(shipping_cost) FROM big_orders WHERE status = 'delivered';
EXPLAIN QUERY PLAN
SELECT SUM(shipping_cost) FROM big_orders WHERE status = 'pending';
```
```text
QUERY PLAN
`--SCAN big_orders
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_status (status=?)
```

Same index, opposite decisions — and both are right: `'delivered'` is 87% of the table (scan), `'pending'` is ~1% (seek). How does it distinguish the two values when `sqlite_stat1` only stores an *average*? This build also keeps per-value histograms:

```sql
SELECT name FROM sqlite_master WHERE name LIKE 'sqlite_stat%';
```
```text
╭──────────────╮
│     name     │
╞══════════════╡
│ sqlite_stat1 │
│ sqlite_stat4 │
╰──────────────╯
```

`sqlite_stat4` (a compile-time option, present here, absent in many distributions) samples individual values, which is how skewed columns get per-value treatment. Don't build schemas that depend on it — §10.10 shows a portable way to handle skew. The habits to take away:

- **Run `ANALYZE` after bulk loads and after creating indexes.** Stale or missing stats mean the planner is guessing.
- When a plan makes no sense, check `sqlite_stat1` first.

> **PostgreSQL note:** same concept, better automation — autovacuum runs `ANALYZE` for you and `pg_stats` exposes per-column histograms and most-common-value lists. After a huge bulk load, a manual `ANALYZE` is still good practice before querying.

## 10.7 Composite indexes and the leftmost-prefix rule

Real queries rarely filter on one column. The "My orders" page actually asks: *customer 682's orders in a date window*. One index on `(customer_id, ordered_at)` serves that better than two single-column indexes, because the index entries are sorted by customer first, then by date *within* each customer — exactly the phone book's `(last_name, first_name)`. Replace the single-column index (a composite starting with `customer_id` makes it redundant):

```sql
DROP INDEX idx_big_orders_customer;
CREATE INDEX idx_big_orders_cust_date ON big_orders (customer_id, ordered_at);
SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'big_orders';
```
```text
╭──────────────────────────╮
│           name           │
╞══════════════════════════╡
│ idx_big_orders_status    │
│ idx_big_orders_cust_date │
╰──────────────────────────╯
```

Now the three ways to query it:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM big_orders
WHERE customer_id = 682 AND ordered_at >= '2026-01-01' AND ordered_at < '2026-07-01';
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE customer_id = 682;
EXPLAIN QUERY PLAN
SELECT * FROM big_orders WHERE ordered_at >= '2026-01-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date (customer_id=? AND ordered_at>? AND ordered_at<?)
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date (customer_id=?)
QUERY PLAN
`--SCAN big_orders
```

This is the **leftmost-prefix rule**:

- `customer_id = ? AND ordered_at <range>` — perfect: equality on the first column narrows to one customer's block, the range walks a slice of it.
- `customer_id = ?` alone — works: it's a prefix of the index order.
- `ordered_at <range>` alone — **useless**: dates are only sorted *within* each customer, not globally. Like finding all Astrids in the phone book.

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_2026 FROM big_orders WHERE ordered_at >= '2026-01-01';"
```
```text
╭─────────────╮
│ orders_2026 │
╞═════════════╡
│      326784 │
╰─────────────╯
Run Time: real 0.024307 user 0.015693 sys 0.008520
```

Back to a 24 ms scan. Design consequence: **column order in a composite index is a decision, not a style choice.** Put equality-filtered columns first, the range/sort column last; a query can seek on a prefix of equalities plus at most one trailing range. (We'll create a proper date index in §10.9, and Pitfall 3 shows the wrong order costing 25×.)

## 10.8 Covering indexes: never touching the table

Each `SEARCH` so far still hops from index entries to table rows to fetch the selected columns. If the index itself contains *every column the query needs*, the engine skips the table entirely. That's a **covering index**, and EQP tells you when it happens:

```sql
EXPLAIN QUERY PLAN
SELECT ordered_at FROM big_orders WHERE customer_id = 682 ORDER BY ordered_at;
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date (customer_id=?)
```

`COVERING INDEX` — the query needs only `customer_id` and `ordered_at`, both in the index. Notice also there's no sort step: the index hands back rows already ordered by `ordered_at` within the customer. Add one more column to the select list and the free lunch ends:

```sql
EXPLAIN QUERY PLAN
SELECT ordered_at, status FROM big_orders WHERE customer_id = 682 ORDER BY ordered_at;
```
```text
QUERY PLAN
`--SEARCH big_orders USING INDEX idx_big_orders_cust_date (customer_id=?)
```

No `COVERING` — `status` lives only in the table, so 6,400 row hops are back. If this exact query is hot (it is: it's the order-history page), append the column to the index:

```sql
CREATE INDEX idx_big_orders_cust_date_status ON big_orders (customer_id, ordered_at, status);
DROP INDEX idx_big_orders_cust_date;
EXPLAIN QUERY PLAN
SELECT ordered_at, status FROM big_orders WHERE customer_id = 682 ORDER BY ordered_at;
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date_status (customer_id=?)
```

We dropped `idx_big_orders_cust_date` in the same breath: the new index starts with the same two columns, so the old one became pure dead weight (leftmost-prefix rule working *for* us). Covering indexes also shine for whole-table aggregation — "top 5 customers by order count" needs three columns, all in the index, so the *scan itself* runs over the narrow index B-tree instead of the wide table:

```sql
EXPLAIN QUERY PLAN
SELECT customer_id, COUNT(*) AS orders, MAX(ordered_at) AS last_order
FROM big_orders
GROUP BY customer_id
ORDER BY orders DESC
LIMIT 5;
```
```text
QUERY PLAN
|--SCAN big_orders USING COVERING INDEX idx_big_orders_cust_date_status
`--USE TEMP B-TREE FOR ORDER BY
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT customer_id, COUNT(*) AS orders, MAX(ordered_at) AS last_order
FROM big_orders
GROUP BY customer_id
ORDER BY orders DESC
LIMIT 5;"
```
```text
╭─────────────┬────────┬─────────────────────╮
│ customer_id │ orders │     last_order      │
╞═════════════╪════════╪═════════════════════╡
│         105 │   6528 │ 2026-06-24 11:56:32 │
│         682 │   6400 │ 2026-07-09 07:45:34 │
│         684 │   6272 │ 2026-07-14 16:21:48 │
│         474 │   5760 │ 2026-06-24 22:40:56 │
│         581 │   5760 │ 2026-06-27 02:59:55 │
╰─────────────┴────────┴─────────────────────╯
Run Time: real 0.043469 user 0.038717 sys 0.004673
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT customer_id, COUNT(*) AS orders, MAX(ordered_at) AS last_order
FROM big_orders NOT INDEXED
GROUP BY customer_id
ORDER BY orders DESC
LIMIT 5;"
```
```text
╭─────────────┬────────┬─────────────────────╮
│ customer_id │ orders │     last_order      │
╞═════════════╪════════╪═════════════════════╡
│         105 │   6528 │ 2026-06-24 11:56:32 │
│         682 │   6400 │ 2026-07-09 07:45:34 │
│         684 │   6272 │ 2026-07-14 16:21:48 │
│         581 │   5760 │ 2026-06-27 02:59:55 │
│         474 │   5760 │ 2026-06-24 22:40:56 │
╰─────────────┴────────┴─────────────────────╯
Run Time: real 0.227854 user 0.201303 sys 0.025925
```

43 ms via the covering index (already grouped in index order, no per-row table hops) versus 228 ms scanning the table and sorting. Don't chase covering for everything — every added column makes the index fatter and writes slower — but for your two or three hottest queries it's the difference between "fast" and "doesn't touch the table at all".

> **PostgreSQL note:** Postgres calls this an Index Only Scan and additionally supports `CREATE INDEX ... INCLUDE (col)` — payload columns stored in the leaves without being part of the sort key. Caveat: index-only scans depend on the visibility map, so freshly written rows may still cause heap fetches until vacuum catches up.

## 10.9 Expression indexes: powerful, rigid

Finance asks: *how many orders did December 2025 have?* The natural first draft uses `strftime`:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';
```
```text
QUERY PLAN
`--SCAN big_orders
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS december_orders FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';"
```
```text
╭─────────────────╮
│ december_orders │
╞═════════════════╡
│           57216 │
╰─────────────────╯
Run Time: real 0.159018 user 0.148883 sys 0.009729
```

159 ms: a scan, *plus* the cost of evaluating `strftime` 768,000 times. SQLite (like Postgres) can index an expression:

```bash
sqlite3 -box scratch.db ".timer on" "CREATE INDEX idx_big_orders_month ON big_orders (strftime('%Y-%m', ordered_at));"
```
```text
Run Time: real 0.332899 user 0.306502 sys 0.025615
```

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_month (<expr>=?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS december_orders FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';"
```
```text
╭─────────────────╮
│ december_orders │
╞═════════════════╡
│           57216 │
╰─────────────────╯
Run Time: real 0.002275 user 0.002270 sys 0.000000
```

70× faster. But expression indexes have an exact-match requirement: the query must contain the *same expression, character for character*. Ask a slightly different question — orders in 2025 — and the index is invisible:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE strftime('%Y', ordered_at) = '2025';
```
```text
QUERY PLAN
`--SCAN big_orders
```

One index, one question shape. For date/time columns there is almost always a better tool: index the **raw column** and phrase every calendar question as a half-open range (the Module 2 habit, now with a performance payoff):

```sql
DROP INDEX idx_big_orders_month;
CREATE INDEX idx_big_orders_ordered_at ON big_orders (ordered_at);
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE ordered_at >= '2025-12-01' AND ordered_at < '2026-01-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_ordered_at (ordered_at>? AND ordered_at<?)
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
Run Time: real 0.002023 user 0.002019 sys 0.000000
```

Same 2 ms — and this one index answers *any* period: a day, a month, Q3, "since Black Friday". One flexible range index beats a family of rigid expression indexes. Save expression indexes for genuinely computed lookups (e.g. `lower(email)` for case-insensitive login).

> **PostgreSQL note:** identical feature (`CREATE INDEX ON t ((expression))`) and identical exact-match requirement. Same advice: prefer indexing raw timestamp columns and querying half-open ranges.

## 10.10 Partial indexes: index only the rows that matter

The ops team's hot query is the fulfilment queue: *pending orders, oldest first*. `status = 'pending'` is ~1% of rows — but our `idx_big_orders_status` pays storage for all 768,000, delivered included:

```sql
SELECT name, ROUND(SUM(pgsize) / 1024.0 / 1024, 1) AS mib
FROM dbstat
WHERE name = 'idx_big_orders_status'
GROUP BY name;
```
```text
╭───────────────────────┬──────╮
│         name          │ mib  │
╞═══════════════════════╪══════╡
│ idx_big_orders_status │ 13.1 │
╰───────────────────────┴──────╯
```

(`dbstat` is a built-in virtual table reporting per-object page usage; if your build lacks it, compare file sizes instead.) 13 MiB, and §10.6 showed the optimizer refuses it for the dominant value anyway. Drop it and index *only the interesting rows* — a **partial index** with a `WHERE` clause, keyed on `ordered_at` so the queue comes out pre-sorted:

```sql
DROP INDEX idx_big_orders_status;
CREATE INDEX idx_big_orders_pending ON big_orders (ordered_at) WHERE status = 'pending';
EXPLAIN QUERY PLAN
SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'pending'
ORDER BY ordered_at
LIMIT 5;
```
```text
QUERY PLAN
`--SCAN big_orders USING INDEX idx_big_orders_pending
```

"SCAN … USING INDEX" reads oddly, but it means: walk this index from the start — and this index only *contains* the ~8,000 pending rows, already in `ordered_at` order. No sort step, and `LIMIT 5` stops after five entries:

```bash
sqlite3 -box scratch.db ".timer on" "SELECT order_id, customer_id, ordered_at
FROM big_orders
WHERE status = 'pending'
ORDER BY ordered_at
LIMIT 5;"
```
```text
╭──────────┬─────────────┬─────────────────────╮
│ order_id │ customer_id │     ordered_at      │
╞══════════╪═════════════╪═════════════════════╡
│     4365 │          63 │ 2026-07-12 13:42:52 │
│    10365 │          63 │ 2026-07-12 13:42:52 │
│    16365 │          63 │ 2026-07-12 13:42:52 │
│    22365 │          63 │ 2026-07-12 13:42:52 │
│    28365 │          63 │ 2026-07-12 13:42:52 │
╰──────────┴─────────────┴─────────────────────╯
Run Time: real 0.000253 user 0.000000 sys 0.000256
```

(The repeated timestamps are our 128× amplification showing through.) And the cost side:

```sql
SELECT name, ROUND(SUM(pgsize) / 1024.0, 0) AS kib
FROM dbstat
WHERE name = 'idx_big_orders_pending'
GROUP BY name;
```
```text
╭────────────────────────┬───────╮
│          name          │  kib  │
╞════════════════════════╪═══════╡
│ idx_big_orders_pending │ 224.0 │
╰────────────────────────┴───────╯
```

224 KiB versus 13.1 MiB — 60× smaller, and rows leaving `'pending'` status simply drop out of it. Partial indexes are the portable answer to skewed columns (no `sqlite_stat4` required) and to any hot-subset workload: unshipped orders, unpaid invoices, rows with `deleted_at IS NULL`. One catch: the query's WHERE clause must let SQLite *prove* the index's condition holds — filter on `status = 'pending'` and it works; filter on `status IN ('pending','paid')` and it can't be used.

> **PostgreSQL note:** partial indexes work identically (`CREATE INDEX ... WHERE ...`) and are a beloved Postgres pattern, e.g. `WHERE NOT processed` job queues.

## 10.11 What indexes cost: writes and space

Indexes are not free lookups sprinkled on top — every `INSERT`, `UPDATE`, `DELETE` must maintain *every* index B-tree on the table. Measure it: two empty clones of `big_orders`, one bare, one carrying our three-index set, bulk-loaded with the same 768,000 rows.

```sql
CREATE TABLE bo_plain (
  order_id      INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL,
  address_id    INTEGER NOT NULL,
  status        TEXT NOT NULL,
  shipping_cost REAL NOT NULL,
  ordered_at    TEXT NOT NULL
);
CREATE TABLE bo_indexed (
  order_id      INTEGER PRIMARY KEY,
  customer_id   INTEGER NOT NULL,
  address_id    INTEGER NOT NULL,
  status        TEXT NOT NULL,
  shipping_cost REAL NOT NULL,
  ordered_at    TEXT NOT NULL
);
CREATE INDEX idx_bo_indexed_cust_date_status ON bo_indexed (customer_id, ordered_at, status);
CREATE INDEX idx_bo_indexed_ordered_at       ON bo_indexed (ordered_at);
CREATE INDEX idx_bo_indexed_pending          ON bo_indexed (ordered_at) WHERE status = 'pending';
SELECT name FROM sqlite_master WHERE tbl_name IN ('bo_plain', 'bo_indexed') AND type = 'index' AND name LIKE 'idx_%';
```
```text
╭─────────────────────────────────╮
│              name               │
╞═════════════════════════════════╡
│ idx_bo_indexed_cust_date_status │
│ idx_bo_indexed_ordered_at       │
│ idx_bo_indexed_pending          │
╰─────────────────────────────────╯
```

```bash
sqlite3 -box scratch.db ".timer on" "INSERT INTO bo_plain SELECT * FROM big_orders;"
```
```text
Run Time: real 0.174350 user 0.149160 sys 0.024713
```

```bash
sqlite3 -box scratch.db ".timer on" "INSERT INTO bo_indexed SELECT * FROM big_orders;"
```
```text
Run Time: real 0.316141 user 0.264434 sys 0.050988
```

Same rows, **1.8× slower** with three indexes to maintain — and this is the friendly case (sorted bulk load). Random single-row writes hit scattered index pages and suffer more. Space:

```sql
SELECT name, ROUND(SUM(pgsize) / 1024.0 / 1024, 1) AS mib
FROM dbstat
WHERE name LIKE 'bo_%' OR name LIKE 'idx_bo_%'
GROUP BY name
ORDER BY name;
DROP TABLE bo_plain;
DROP TABLE bo_indexed;
```
```text
╭─────────────────────────────────┬──────╮
│              name               │ mib  │
╞═════════════════════════════════╪══════╡
│ bo_indexed                      │ 36.9 │
│ bo_plain                        │ 36.9 │
│ idx_bo_indexed_cust_date_status │ 30.0 │
│ idx_bo_indexed_ordered_at       │ 20.6 │
│ idx_bo_indexed_pending          │  0.2 │
╰─────────────────────────────────┴──────╯
```

The two big indexes weigh 50 MiB against a 37 MiB table — the indexed copy is well over double the storage. The rule that falls out: **every index must be justified by a query you actually run.** An index is a bet that its read savings outweigh its permanent write and space tax; unread indexes only pay the tax. (Note the partial index again: 0.2 MiB, nearly free on both axes.)

## 10.12 Join performance: index the foreign key you join on

Joins execute (in SQLite; conceptually in most row stores) as nested loops: for each row of the outer table, find matching rows in the inner table. If that inner lookup has no index, *every* outer row triggers a scan-or-worse on the inner side — this is where missing indexes hurt most, because the cost multiplies.

Merchandising asks: *top 5 tent models by units sold, all time* (`category_id = 2` is Tents). The join column on the big side is `big_order_items.product_id` — currently unindexed (the composite PK `(order_id, product_id)` doesn't help: `product_id` is not a leftmost prefix).

```sql
EXPLAIN QUERY PLAN
SELECT p.name, SUM(oi.quantity) AS units
FROM products AS p
JOIN big_order_items AS oi ON oi.product_id = p.product_id
WHERE p.category_id = 2
GROUP BY p.product_id
ORDER BY units DESC
LIMIT 5;
```
```text
QUERY PLAN
|--SCAN oi
|--BLOOM FILTER ON p (product_id=?)
|--SEARCH p USING INTEGER PRIMARY KEY (rowid=?)
|--USE TEMP B-TREE FOR GROUP BY
`--USE TEMP B-TREE FOR ORDER BY
```

Read multi-line plans top-down: the first line is the outer loop. SQLite had no way to go *from products into the line items*, so it inverted the join: scan all 1.7M line items, and probe `products` for each (the bloom filter is a cheap pre-check that discards most non-tent probes early — clever, but still a 1.7M-row scan).

```bash
sqlite3 -box scratch.db ".timer on" "SELECT p.name, SUM(oi.quantity) AS units
FROM products AS p
JOIN big_order_items AS oi ON oi.product_id = p.product_id
WHERE p.category_id = 2
GROUP BY p.product_id
ORDER BY units DESC
LIMIT 5;"
```
```text
╭────────────────────┬───────╮
│        name        │ units │
╞════════════════════╪═══════╡
│ Basecamp Dome Tent │ 30080 │
│ Nordic Tent 3P     │ 23808 │
│ Basecamp Tent 3P   │ 20480 │
│ Trail Dome Tent    │ 17024 │
│ Storm Tent 2P      │ 13312 │
╰────────────────────┴───────╯
Run Time: real 0.087263 user 0.077389 sys 0.009612
```

Now give the join a door to walk through:

```bash
sqlite3 -box scratch.db ".timer on" "CREATE INDEX idx_big_order_items_product ON big_order_items (product_id);"
```
```text
Run Time: real 0.342300 user 0.317654 sys 0.023991
```

```sql
EXPLAIN QUERY PLAN
SELECT p.name, SUM(oi.quantity) AS units
FROM products AS p
JOIN big_order_items AS oi ON oi.product_id = p.product_id
WHERE p.category_id = 2
GROUP BY p.product_id
ORDER BY units DESC
LIMIT 5;
```
```text
QUERY PLAN
|--SCAN p
|--SEARCH oi USING INDEX idx_big_order_items_product (product_id=?)
`--USE TEMP B-TREE FOR ORDER BY
```

The plan flipped: drive from the 350-row `products` table (scanning *that* is nothing), and for each tent, seek straight to its line items.

```bash
sqlite3 -box scratch.db ".timer on" "SELECT p.name, SUM(oi.quantity) AS units
FROM products AS p
JOIN big_order_items AS oi ON oi.product_id = p.product_id
WHERE p.category_id = 2
GROUP BY p.product_id
ORDER BY units DESC
LIMIT 5;"
```
```text
╭────────────────────┬───────╮
│        name        │ units │
╞════════════════════╪═══════╡
│ Basecamp Dome Tent │ 30080 │
│ Nordic Tent 3P     │ 23808 │
│ Basecamp Tent 3P   │ 20480 │
│ Trail Dome Tent    │ 17024 │
│ Storm Tent 2P      │ 13312 │
╰────────────────────┴───────╯
Run Time: real 0.013951 user 0.010851 sys 0.003054
```

87 ms → 14 ms, and the gap widens with table size. **Rule: index the foreign-key columns you join on** — the child side (`order_items.product_id`, `orders.customer_id`); the parent side is already a PK. Multi-table joins compose the same way — here's December 2025 gross revenue by tent model (canonical definition: item revenue, cancelled orders excluded), joining all three tables:

```sql
EXPLAIN QUERY PLAN
SELECT p.name,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
JOIN products        AS p  ON p.product_id = oi.product_id
WHERE o.ordered_at >= '2025-12-01' AND o.ordered_at < '2026-01-01'
  AND o.status <> 'cancelled'
  AND p.category_id = 2
GROUP BY p.product_id
ORDER BY gross_revenue DESC
LIMIT 3;
```
```text
QUERY PLAN
|--SCAN p
|--SEARCH oi USING INDEX idx_big_order_items_product (product_id=?)
|--SEARCH o USING INTEGER PRIMARY KEY (rowid=?)
`--USE TEMP B-TREE FOR ORDER BY
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT p.name,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM big_orders AS o
JOIN big_order_items AS oi ON oi.order_id = o.order_id
JOIN products        AS p  ON p.product_id = oi.product_id
WHERE o.ordered_at >= '2025-12-01' AND o.ordered_at < '2026-01-01'
  AND o.status <> 'cancelled'
  AND p.category_id = 2
GROUP BY p.product_id
ORDER BY gross_revenue DESC
LIMIT 3;"
```
```text
╭────────────────────────┬───────────────╮
│          name          │ gross_revenue │
╞════════════════════════╪═══════════════╡
│ Nordic Tunnel Tent     │     1050624.0 │
│ Nordic Ultralight Tent │     784470.02 │
│ Basecamp Dome Tent     │     707932.22 │
╰────────────────────────┴───────────────╯
Run Time: real 0.136231 user 0.060922 sys 0.074651
```

Every join hop is a `SEARCH` — small outer table, indexed FK into the line items, PK into orders. When you diagnose a slow multi-join, look for the one line that says `SCAN <big table>`; that's almost always the missing FK index.

> **PostgreSQL note:** Postgres also does *not* auto-index FK columns (only the referenced side's PK/UNIQUE). Beyond nested loops it can pick hash or merge joins, which soften a missing index for big one-off analytics — but OLTP-style joins and FK constraint checks (especially cascading deletes) still want the child-side index.

## 10.13 Sargability: write predicates the optimizer can use

A predicate is **sargable** (search-argument-able) when the engine can map it onto an index seek. The recurring killers are wrapping the column in a function (Pitfall 1), leading-wildcard `LIKE` (Pitfall 2) — and `OR`. SQLite can sometimes serve a disjunction with two seeks, one per branch:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE customer_id = 682 OR ordered_at >= '2026-07-10';
```
```text
QUERY PLAN
`--MULTI-INDEX OR
   |--INDEX 1
   |  `--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date_status (customer_id=?)
   `--INDEX 2
      `--SEARCH big_orders USING INDEX idx_big_orders_ordered_at (ordered_at>?)
```

That works because *both* branches are independently indexable. Make one branch unindexable and the whole query collapses to a scan — `OR` is all-or-nothing:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE customer_id = 682 OR address_id = 999;
```
```text
QUERY PLAN
`--SCAN big_orders
```

`address_id` has no index, so even the indexed `customer_id` branch can't be used. Two fixes, in order of preference: index the unindexed branch (you'll do exactly this in Exercise 5), or — the classic portable rewrite when you can't add indexes — split the `OR` into two SELECTs combined with `UNION`, so each branch gets its own plan (`UNION`, not `UNION ALL`: a row matching both branches must not be counted twice, and `UNION` deduplicates just like `OR` semantics require).

Two related conceptual points to file away:

- **`EXISTS` vs `IN`:** a correlated `EXISTS (SELECT 1 ...)` can stop at the first matching row per outer row (early exit) and typically rides the inner table's index; `IN (SELECT ...)` conceptually materializes the whole inner set first. Modern optimizers (SQLite included) usually rewrite one into the other, so decide by clarity and correctness first — but when a plan shows the inner query materialized into a temp structure that dwarfs the rows you need, try the `EXISTS` form. (And `NOT IN` still has the NULL trap from Module 4 — one more reason `NOT EXISTS` is the safer default.)
- **The optimizer ignoring your index is often correct.** You've now seen the three honest reasons: the table is small (§10.3), the predicate isn't selective (§10.5), or the predicate isn't sargable as written (this section). Check those three before assuming the planner is broken.

## Pitfalls

### Pitfall 1: wrapping an indexed column in a function

Finance wants order count for 1 December 2025. `date()` makes the intent beautifully clear — and disables the index, because the index stores `ordered_at` values, not `date(ordered_at)` results:

```sql
-- BAD: date() wrapped around an indexed column disables the index
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders WHERE date(ordered_at) = '2025-12-01';
```
```text
QUERY PLAN
`--SCAN big_orders USING COVERING INDEX idx_big_orders_ordered_at
```

Note carefully: `SCAN ... USING COVERING INDEX` is still a **SCAN** — it reads all 768,000 index entries and runs `date()` on each; it merely walks the (narrower) index instead of the table. The verb is what matters, not the word INDEX.

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_that_day FROM big_orders WHERE date(ordered_at) = '2025-12-01';"
```
```text
╭─────────────────╮
│ orders_that_day │
╞═════════════════╡
│            1664 │
╰─────────────────╯
Run Time: real 0.068866 user 0.057754 sys 0.011006
```

The fix is the Module 2 half-open range — compare the *raw column* against constants, and the index seeks:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE ordered_at >= '2025-12-01' AND ordered_at < '2025-12-02';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_ordered_at (ordered_at>? AND ordered_at<?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_that_day FROM big_orders
WHERE ordered_at >= '2025-12-01' AND ordered_at < '2025-12-02';"
```
```text
╭─────────────────╮
│ orders_that_day │
╞═════════════════╡
│            1664 │
╰─────────────────╯
Run Time: real 0.000305 user 0.000307 sys 0.000000
```

Same 1,664 orders, 226× faster. The general rule: **functions go on the constant side of the comparison, never on the column side.** (`ordered_at >= date('2025-12-01')` is fine — that function runs once, on a constant.)

### Pitfall 2: leading-wildcard LIKE

Catalog search: "everything with *tent* in the name". Give `products.name` an index first (`COLLATE NOCASE` so it matches `LIKE`'s default case-insensitivity — a plain binary index cannot serve case-insensitive `LIKE` at all):

```sql
CREATE INDEX idx_products_name ON products (name COLLATE NOCASE);
SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'products' AND name LIKE 'idx_%';
```
```text
╭───────────────────╮
│       name        │
╞═══════════════════╡
│ idx_products_name │
╰───────────────────╯
```

```sql
-- BAD: a leading wildcard can never use an index
EXPLAIN QUERY PLAN
SELECT product_id, name FROM products WHERE name LIKE '%tent%';
```
```text
QUERY PLAN
`--SCAN products USING COVERING INDEX idx_products_name
```

A SCAN again — necessarily: an index is sorted by how strings *begin*, and `'%tent%'` says "the match can start anywhere". No B-tree in any database can seek on that. A *prefix* pattern, by contrast, is just a disguised range (`'storm%'` ≡ `>= 'storm' AND < 'stornn'`… roughly), and the index serves it:

```sql
EXPLAIN QUERY PLAN
SELECT product_id, name FROM products WHERE name LIKE 'storm%';
```
```text
QUERY PLAN
`--SEARCH products USING COVERING INDEX idx_products_name (name>? AND name<?)
```

```sql
SELECT product_id, name FROM products WHERE name LIKE 'storm%';
DROP INDEX idx_products_name;
```
```text
╭────────────┬───────────────────────╮
│ product_id │         name          │
╞════════════╪═══════════════════════╡
│        150 │ Storm Dome Tent       │
│         39 │ Storm Down Jacket     │
│         29 │ Storm Insulated Parka │
│        305 │ Storm Rain Jacket     │
│         61 │ Storm Tent 2P         │
│        182 │ Storm Tent 3P         │
│        350 │ Storm Tunnel Tent     │
│        257 │ Storm Ultralight Tent │
│        331 │ Storm Wind Shell      │
╰────────────┴───────────────────────╯
```

On 350 products the scan was harmless anyway (§10.3 — we drop the index again for that reason); on millions of rows of event or log text it is not. If the business genuinely needs substring or word search, the answer is not an index at all but a full-text engine — SQLite ships one as the FTS5 extension (beyond this course's scope, but worth knowing the name).

> **PostgreSQL note:** in Postgres, plain B-tree indexes don't accelerate `LIKE` under most collations — you need `text_pattern_ops` for prefix patterns, and the `pg_trgm` extension (GIN trigram index) is the standard fix for true `'%tent%'` searches.

### Pitfall 3: composite index with the wrong column order

Someone "optimizes" the order-history query with an index on `(ordered_at, customer_id)` — same two columns as our good index, opposite order. Both *can* be used; they are not remotely equivalent. Create it and force it with `INDEXED BY` (a diagnostic clause that demands a specific index — useful precisely for what-if comparisons like this):

```sql
CREATE INDEX idx_big_orders_date_cust ON big_orders (ordered_at, customer_id);
SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'big_orders' AND name LIKE 'idx_%';
```
```text
╭─────────────────────────────────╮
│              name               │
╞═════════════════════════════════╡
│ idx_big_orders_cust_date_status │
│ idx_big_orders_ordered_at       │
│ idx_big_orders_pending          │
│ idx_big_orders_date_cust        │
╰─────────────────────────────────╯
```

```sql
-- BAD: range column first, equality column second — forced here to show the cost
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders INDEXED BY idx_big_orders_date_cust
WHERE customer_id = 682
  AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_date_cust (ordered_at>? AND ordered_at<?)
```

Look at the parenthesis: only the *date range* narrows the seek. The index dives into "2025" and then crawls every 2025 entry — a couple hundred thousand — checking `customer_id` on each, because within a date range customers are in no useful order. The equality column trapped behind a range is wasted.

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_2025 FROM big_orders INDEXED BY idx_big_orders_date_cust
WHERE customer_id = 682
  AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01';"
```
```text
╭─────────────╮
│ orders_2025 │
╞═════════════╡
│        3584 │
╰─────────────╯
Run Time: real 0.010800 user 0.009028 sys 0.001700
```

Left to itself, the optimizer picks the right-ordered index — equality first, range second, both columns narrowing the seek:

```sql
EXPLAIN QUERY PLAN
SELECT COUNT(*) FROM big_orders
WHERE customer_id = 682
  AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01';
```
```text
QUERY PLAN
`--SEARCH big_orders USING COVERING INDEX idx_big_orders_cust_date_status (customer_id=? AND ordered_at>? AND ordered_at<?)
```

```bash
sqlite3 -box scratch.db ".timer on" "SELECT COUNT(*) AS orders_2025 FROM big_orders
WHERE customer_id = 682
  AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01';"
```
```text
╭─────────────╮
│ orders_2025 │
╞═════════════╡
│        3584 │
╰─────────────╯
Run Time: real 0.000378 user 0.000380 sys 0.000000
```

28× faster for the identical rows. Mantra from §10.7, now proven: **equality columns first, the range column last.** Clean up the bad idea:

```sql
DROP INDEX idx_big_orders_date_cust;
SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'big_orders' AND name LIKE 'idx_%';
```
```text
╭─────────────────────────────────╮
│              name               │
╞═════════════════════════════════╡
│ idx_big_orders_cust_date_status │
│ idx_big_orders_ordered_at       │
│ idx_big_orders_pending          │
╰─────────────────────────────────╯
```

### Pitfall 4: indexing everything "just in case"

The tempting failure mode after learning indexes: sprinkle them everywhere.

```sql
-- BAD: an index nothing in the workload asks for
CREATE INDEX idx_big_orders_shipping ON big_orders (shipping_cost);
SELECT name, ROUND(SUM(pgsize) / 1024.0 / 1024, 1) AS mib
FROM dbstat
WHERE name = 'idx_big_orders_shipping'
GROUP BY name;
```
```text
╭─────────────────────────┬──────╮
│          name           │ mib  │
╞═════════════════════════╪══════╡
│ idx_big_orders_shipping │ 10.5 │
╰─────────────────────────┴──────╯
```

No query in our workload filters or sorts by `shipping_cost` alone — yet from this moment it costs 10.5 MiB forever and taxes *every single write* (§10.11 measured that tax at roughly +80% for three indexes; each additional one stacks). This is **write amplification**: one logical row insert becomes N physical B-tree inserts. And an unused index isn't even harmless at read time — it's one more plan the optimizer must consider, and (pre-`ANALYZE`) might wrongly trust.

```sql
DROP INDEX idx_big_orders_shipping;
```
```text
(no output)
```

The discipline: indexes are driven by the **workload**, never by the schema. Start from your actual queries, add the smallest set that serves them (exploiting leftmost prefixes so one composite serves several queries), verify each with EQP, and delete indexes no plan uses.

## Housekeeping: leave the statistics fresh

We created and dropped a dozen indexes; the statistics from §10.6 describe a world that no longer exists. Whenever the index set or the data changes materially, refresh:

```bash
sqlite3 -box scratch.db ".timer on" "ANALYZE;"
```
```text
Run Time: real 0.330447 user 0.284739 sys 0.045174
```

```sql
SELECT * FROM sqlite_stat1 WHERE tbl LIKE 'big_%' ORDER BY idx;
```
```text
╭─────────────────┬────────────────────────────────────┬─────────────────────╮
│       tbl       │                idx                 │        stat         │
╞═════════════════╪════════════════════════════════════╪═════════════════════╡
│ big_order_items │ idx_big_order_items_product        │ 1724800 5582        │
│ big_orders      │ idx_big_orders_cust_date_status    │ 768000 1138 128 128 │
│ big_orders      │ idx_big_orders_ordered_at          │ 768000 128          │
│ big_orders      │ idx_big_orders_pending             │ 8064 128            │
│ big_order_items │ sqlite_autoindex_big_order_items_1 │ 1724800 3 1         │
╰─────────────────┴────────────────────────────────────┴─────────────────────╯
```

This is the final state of the lab: four deliberate indexes, each tied to a named query pattern. The exercises below start from exactly this state — solve them in order, since some fixes you create are reused by later plans.

## Exercises

Work against `scratch.db` in its end-of-module state. For every "diagnose and fix" exercise: run `EXPLAIN QUERY PLAN` and `.timer on` timings **before and after** your fix, and be able to say in one sentence *why* the original was slow. A fix is either a new index or a rewrite of the query — never both unless truly needed, and never a fix you can't justify against §10.11's cost rules.

**Warm-up**

1. Without running EQP first, predict `SCAN` or `SEARCH` for each of these, then verify: (a) the details of order 300000; (b) all orders with free shipping (`shipping_cost = 0`); (c) customer 105's orders placed on or after 2026-03-01.
2. Support wants a list of all Swedish customers. Time the query on `customers`. Would you create an index on `customers(country)` to support it? Give the reasoning, not just the answer.
3. Using only the leftmost-prefix rule, predict for each predicate whether `idx_big_orders_cust_date_status` can power a `SEARCH`, then verify: (a) `customer_id = 682`; (b) `customer_id = 682 AND ordered_at >= '2026-01-01'`; (c) `ordered_at >= '2026-01-01'`; (d) `customer_id = 682 AND status = 'delivered'`. For (d), explain what the index can and cannot do for the `status` filter.

**Core — six slow queries to diagnose and fix**

4. Finance runs this Q1-2024 gross-revenue report (canonical definition) and complains it's slow. Diagnose and fix by rewrite:
   ```sql
   SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
   FROM big_orders AS o
   JOIN big_order_items AS oi ON oi.order_id = o.order_id
   WHERE strftime('%Y', o.ordered_at) = '2024'
     AND strftime('%m', o.ordered_at) IN ('01', '02', '03')
     AND o.status <> 'cancelled';
   ```
5. Logistics asks: *how many delivered orders have shipped to Innsbruck addresses?* Their query joins `addresses` to `big_orders` on `address_id` and filters `a.city = 'Innsbruck' AND o.status = 'delivered'`. Diagnose why the plan scans 768,000 orders and fix it with one index. (Your fix also repairs the `OR` query from §10.13 — check it with EQP if you're curious.)
6. Ops wants daily order counts for June 2026. Their draft is below. Diagnose and fix by rewrite — and explain why keeping `date()` in the SELECT and GROUP BY is fine while keeping it in WHERE is not:
   ```sql
   SELECT date(ordered_at) AS day, COUNT(*) AS orders
   FROM big_orders
   WHERE date(ordered_at) BETWEEN '2026-06-01' AND '2026-06-30'
   GROUP BY day;
   ```
7. The returns team polls for the 10 most recent `'returned'` orders (`ORDER BY ordered_at DESC LIMIT 10`) every few seconds. Diagnose why it's slow and fix it with the cheapest index that makes it near-instant. Why is a plain index on `status` the wrong answer here?
8. Merchandising audits deep discounts: units sold per discount tier for tiers of 15% and up, from `big_order_items`. The query (`WHERE discount_pct >= 15 GROUP BY discount_pct`, summing `quantity`) scans 1.7M rows. Fix it with a single index that lets the query never touch the table, and prove that property from the plan.
9. An analyst counts December-2025 orders with `WHERE ordered_at LIKE '2025-12%'` and insists it should be fast "because ordered_at is indexed". Explain precisely why this `LIKE` cannot use `idx_big_orders_ordered_at` (two reasons — think §10.13 and Pitfall 2), then rewrite it to seek.

**Challenge**

10. Design the minimal index set for `big_orders` + `big_order_items` to serve this workload, assuming *none* of the module's indexes exist yet: (a) order lookup by id including its line items; (b) a customer's order history, newest first; (c) the pending-orders queue, oldest first; (d) gross revenue for an arbitrary date range; (e) all-time units sold for a given product; (f) a nightly bulk load of ~5,000 new orders. Name each index, justify it with the query pattern it serves and the leftmost-prefix reasoning, state what you deliberately did **not** index, and verify with EQP that each pattern gets a SEARCH (or a justified scan).
11. For each query below, predict which index (if any) the optimizer uses, and whether the plan says COVERING — then verify: (a) `SELECT status, COUNT(*) FROM big_orders WHERE customer_id = 682 GROUP BY status;` (b) `SELECT COUNT(*) FROM big_orders WHERE status = 'pending' AND ordered_at >= '2026-06-01';` (c) `SELECT COUNT(*) FROM big_orders WHERE strftime('%Y-%m', ordered_at) = '2025-12';`

## Key takeaways

- **B-tree index** = sorted copy of chosen columns + row pointers: O(log n) seeks, cheap ranges, ordered output. Every SQLite table is itself a B-tree on `rowid`; `INTEGER PRIMARY KEY` aliases it, so PK lookups need no extra index.
- **`EXPLAIN QUERY PLAN`**: `SEARCH` = seek (good); `SCAN` = read everything (fine only for small tables or most-of-table reads). `SCAN ... USING COVERING INDEX` is still a scan. Workflow: `.eqp on` + `.timer on`; measure before and after every change.
- **Selectivity decides.** Index columns where one value ≈ small fraction of rows. Low-selectivity indexes make queries *slower* (per-row table hops beat nothing out of a sequential read).
- **`ANALYZE`** populates `sqlite_stat1` so the planner estimates instead of guessing. Re-run after bulk loads and index changes.
- **Composite indexes**: leftmost-prefix rule; equality columns first, one range/sort column last; `(a, b)` makes a separate `(a)` redundant.
- **Covering index**: index contains all referenced columns → table never touched. **Expression index**: works only for the character-identical expression; prefer a raw-column index + half-open ranges for dates. **Partial index** (`CREATE INDEX ... WHERE ...`): tiny, perfect for hot skewed subsets like status queues.
- **Costs**: every index taxes every write (≈1.8× slower bulk load with 3 indexes here) and takes real space (50 MiB of index on a 37 MiB table). No index without a query that earns it.
- **Joins**: index the child-side FK you join on; in a slow join plan, hunt the `SCAN <big table>` line.
- **Sargability**: never wrap the filtered column in a function (`date(col) = x` → `col >= x AND col < x+1`); leading-wildcard `LIKE` can never seek; `OR` needs *every* branch indexable (else split with `UNION`); prefer `EXISTS`/`NOT EXISTS` over `IN`/`NOT IN` for correlated membership.
- Syntax: `CREATE INDEX idx_t_cols ON t (a, b);` · `CREATE INDEX ... ON t (expr);` · `CREATE INDEX ... ON t (a) WHERE cond;` · `DROP INDEX idx;` · `ANALYZE;` · diagnostics: `EXPLAIN QUERY PLAN`, `NOT INDEXED`, `INDEXED BY`, `dbstat`.
