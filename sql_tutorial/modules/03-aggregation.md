# Module 3 — Aggregation

So far every query returned individual rows. But almost every business question — "how much revenue last month?", "which payment method fails most?", "what's our cancellation rate?" — is a question about *groups* of rows, not rows themselves. Aggregation is how SQL collapses many rows into a few numbers, and it is the single most-used skill in analytical SQL. It is also where subtle bugs creep in: NULLs silently vanish from averages, `COUNT` undercounts, and SQLite will happily run queries that are semantically broken. This module teaches you both the mechanics and the failure modes.

All queries run read-only against `shop.db`:

```bash
cd ~/personal/tutorials/sql_tutorial
sqlite3 -box shop.db
```

## What you'll learn

- The five core aggregates: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- `COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT col)` — three different questions
- How aggregates treat NULL, and why `AVG(col)` ≠ `SUM(col) / COUNT(*)`
- `GROUP BY` on one column, several columns, and computed expressions (e.g. month buckets)
- The split-apply-combine mental model
- The golden rule: every selected non-aggregate column belongs in `GROUP BY` — and SQLite's dangerous leniency about it
- `HAVING` vs `WHERE`: filtering groups vs filtering rows, and combining both
- Sorting results by aggregate values
- Conditional aggregation with `CASE` inside `SUM`/`COUNT`/`AVG` — pivot-style reports in plain SQL
- Displaying money properly with `ROUND` and `printf`

## Aggregates collapse rows into one

An aggregate function consumes a set of rows and produces a single value. The simplest one answers "how many rows?":

```sql
SELECT COUNT(*) AS total_orders
FROM orders;
```

```text
╭──────────────╮
│ total_orders │
╞══════════════╡
│         6000 │
╰──────────────╯
```

6,000 input rows, one output row. That collapse is the defining behavior of aggregation: once an aggregate appears in the `SELECT` list (and there's no `GROUP BY` yet), the whole table becomes **one group**, and you get one row back.

## The three faces of COUNT

`COUNT` comes in three flavors, and they answer three different questions:

- `COUNT(*)` — how many **rows** are there?
- `COUNT(col)` — how many rows have a **non-NULL** value in `col`?
- `COUNT(DISTINCT col)` — how many **different** non-NULL values does `col` take?

About 29% of Nordkart customers never gave us a phone number. Watch all three claims come from one query — how many customers do we have, and how many can our support team actually call?

```sql
SELECT
  COUNT(*)                AS all_customers,
  COUNT(phone)            AS have_phone,
  COUNT(*) - COUNT(phone) AS missing_phone
FROM customers;
```

```text
╭───────────────┬────────────┬───────────────╮
│ all_customers │ have_phone │ missing_phone │
╞═══════════════╪════════════╪═══════════════╡
│           800 │        569 │           231 │
╰───────────────┴────────────┴───────────────╯
```

`COUNT(phone)` skipped 231 rows because their `phone` is NULL. This is a feature when you're asking "how many customers are reachable by phone", and a bug when you meant "how many customers" — we'll demonstrate that failure in the Pitfalls section.

`COUNT(DISTINCT ...)` deduplicates before counting. A merchandising question: how many order lines have we ever written, how many orders do they belong to, and how many *different* products have actually sold?

```sql
SELECT
  COUNT(*)                    AS order_lines,
  COUNT(DISTINCT order_id)    AS orders_with_items,
  COUNT(DISTINCT product_id)  AS products_ever_sold
FROM order_items;
```

```text
╭─────────────┬───────────────────┬────────────────────╮
│ order_lines │ orders_with_items │ products_ever_sold │
╞═════════════╪═══════════════════╪════════════════════╡
│       13475 │              6000 │                309 │
╰─────────────┴───────────────────┴────────────────────╯
```

Interpretation: 13,475 lines spread over all 6,000 orders (~2.2 lines per order), but only 309 of Nordkart's 350 products have ever appeared on an order — 41 products have never sold. Finding *which* ones needs a join (Module 4); counting them needs only `COUNT(DISTINCT)`.

## SUM, AVG, MIN, MAX

The numeric aggregates work the way you'd expect — with one Nordkart-specific trap: **refunds are stored as negative payment amounts**, so a plain `SUM` over payments gives you *net* cash, not gross.

How much money has actually moved through captured payments?

```sql
SELECT
  COUNT(*)             AS captured_payments,
  ROUND(SUM(amount),2) AS net_cash,
  ROUND(AVG(amount),2) AS avg_amount,
  MIN(amount)          AS smallest,
  MAX(amount)          AS largest
FROM payments
WHERE status = 'captured';
```

```text
╭───────────────────┬────────────┬────────────┬──────────┬─────────╮
│ captured_payments │  net_cash  │ avg_amount │ smallest │ largest │
╞═══════════════════╪════════════╪════════════╪══════════╪═════════╡
│              5794 │ 2995919.15 │     517.07 │ -2774.63 │ 4629.29 │
╰───────────────────┴────────────┴────────────┴──────────┴─────────╯
```

Read that `smallest` value carefully: it's **negative** — a €2,774.63 refund. The `SUM` therefore already nets refunds against sales, which matches the *net revenue* idea from `DATASET.md`'s canonical definitions ("gross + negative refund amounts on the payments side"). If you wanted gross inflow only, you'd need to separate positive from negative amounts — conditional aggregation, coming up below.

Also note `WHERE` and aggregates compose naturally: `WHERE` throws away rows *first*, then the aggregates see only what survived.

### A quick but vital detour: integer division

Nordkart stores `discount_pct` as an INTEGER (0–20). Recall the trap from Module 1: in SQL, dividing two integers yields an integer:

```sql
SELECT 15 / 100 AS integer_division, 15 / 100.0 AS float_division;
```

```text
╭──────────────────┬────────────────╮
│ integer_division │ float_division │
╞══════════════════╪════════════════╡
│                0 │           0.15 │
╰──────────────────┴────────────────╯
```

`15 / 100` is `0`. If you compute discounts with `discount_pct / 100`, every discount silently becomes zero and your revenue numbers are wrong *without any error*. This is why the canonical **item revenue** formula in `DATASET.md` is written with a float literal:

```
quantity * unit_price * (1 - discount_pct / 100.0)
```

Always write `100.0` (or multiply by `1.0` first). This applies to percentages too: `failed_count / total_count` is integer division; use `100.0 * failed / total`.

> **PostgreSQL note:** identical behavior — `integer / integer` truncates in PostgreSQL too. This trap is portable.

### Displaying money: ROUND vs printf

`ROUND(x, 2)` returns a **number** rounded to 2 decimals — still usable in arithmetic and sorts numerically. `printf(format, x)` returns **text** — great for the final display column, but it sorts alphabetically ('9' > '10') and can't be summed. Rule of thumb: compute with numbers, `ROUND` for readable output, `printf` only for the outermost presentation layer.

```sql
SELECT
  ROUND(SUM(amount), 2)         AS rounded_number,
  printf('%.2f', SUM(amount))   AS formatted_text,
  printf('%,.2f', SUM(amount))  AS grouped_text
FROM payments
WHERE status = 'captured' AND amount > 0;
```

```text
╭────────────────┬────────────────┬──────────────╮
│ rounded_number │ formatted_text │ grouped_text │
╞════════════════╪════════════════╪══════════════╡
│     3084271.89 │ 3084271.89     │ 3,084,271.89 │
╰────────────────┴────────────────┴──────────────╯
```

The `,` flag adds thousands separators. Notice the box alignment: `rounded_number` is right-aligned (a number), the printf results are left-aligned (text). That alignment difference is the CLI telling you the type changed. And here's gross inflow (€3.08M) vs the net €3.00M above — the €88K gap is refunds.

> **PostgreSQL note:** `round(x, 2)` on a `double precision` errors in PostgreSQL — you must cast: `round(x::numeric, 2)`. For display formatting use `to_char(x, 'FM9,999,990.00')` instead of `printf`.

## Aggregates ignore NULL — and what that does to AVG

Every aggregate except `COUNT(*)` **skips NULL inputs entirely**. They aren't counted, summed, or averaged — it's as if those rows didn't exist for that particular aggregate.

The `shipments` table shows why this is usually right: `delivered_at` is NULL for parcels still in transit. Business question: how long does delivery take on average? (`julianday()` converts a timestamp to a fractional day number, so subtracting two gives the gap in days — subtracting a NULL gives NULL.)

```sql
SELECT
  COUNT(*)                       AS shipments,
  COUNT(delivered_at)            AS delivered,
  COUNT(*) - COUNT(delivered_at) AS in_transit,
  ROUND(AVG(julianday(delivered_at) - julianday(shipped_at)), 2) AS avg_days_to_deliver
FROM shipments;
```

```text
╭───────────┬───────────┬────────────┬─────────────────────╮
│ shipments │ delivered │ in_transit │ avg_days_to_deliver │
╞═══════════╪═══════════╪════════════╪═════════════════════╡
│      5532 │      5379 │        153 │                5.47 │
╰───────────┴───────────┴────────────┴─────────────────────╯
```

`AVG` averaged over the 5,379 *delivered* shipments and ignored the 153 in-transit NULLs — exactly what "average delivery time" should mean. Perfect.

But this means `AVG(col)` and `SUM(col) / COUNT(*)` are **different formulas** whenever NULLs exist. `AVG` divides by the count of non-NULL values; the manual version divides by all rows:

```sql
SELECT
  ROUND(AVG(julianday(delivered_at) - julianday(shipped_at)), 3)            AS avg_skips_nulls,
  ROUND(SUM(julianday(delivered_at) - julianday(shipped_at)) / COUNT(*), 3) AS sum_over_all_rows
FROM shipments;
```

```text
╭─────────────────┬───────────────────╮
│ avg_skips_nulls │ sum_over_all_rows │
╞═════════════════╪═══════════════════╡
│           5.469 │             5.317 │
╰─────────────────┴───────────────────╯
```

5.469 vs 5.317 — same table, two answers. Neither is "the" average; they answer different questions ("average time *among delivered parcels*" vs "delivered days spread over *all* shipments", which here is meaningless). The dangerous case is when NULL should mean **zero** for your question — then `AVG` silently gives the wrong business answer and you need `COALESCE`. That's Pitfall 3 below.

One more NULL rule worth knowing: over an **empty** input set, `COUNT` returns 0 but `SUM`/`AVG`/`MIN`/`MAX` return NULL:

```sql
SELECT COUNT(*) AS n, SUM(amount) AS total, MAX(amount) AS biggest
FROM payments
WHERE method = 'bitcoin';
```

```text
╭───┬───────┬─────────╮
│ n │ total │ biggest │
╞═══╪═══════╪═════════╡
│ 0 │       │         │
╰───┴───────┴─────────╯
```

Nordkart takes no bitcoin, so `SUM` returns NULL, not 0. If a downstream system expects a number, wrap it: `COALESCE(SUM(amount), 0)`.

## GROUP BY: split, apply, combine

`GROUP BY` turns "one number for the whole table" into "one number **per group**". The mental model is *split–apply–combine*:

1. **Split** the rows into buckets — one bucket per distinct value of the grouping column(s).
2. **Apply** the aggregate functions to each bucket independently.
3. **Combine** the per-bucket results into the output: **one row per bucket**.

Business question: what does our order pipeline look like by status?

```sql
SELECT status, COUNT(*) AS n_orders
FROM orders
GROUP BY status;
```

```text
╭───────────┬──────────╮
│  status   │ n_orders │
╞═══════════╪══════════╡
│ cancelled │      315 │
│ delivered │     5207 │
│ paid      │       90 │
│ pending   │       63 │
│ returned  │      172 │
│ shipped   │      153 │
╰───────────┴──────────╯
```

Six distinct statuses → six buckets → six output rows. The vast majority of orders end delivered; 315 (5.25%) were cancelled — remember from `DATASET.md` that cancelled orders are **excluded from gross revenue**, so this status column will matter in every revenue query you ever write against this database.

### Ordering by an aggregate

Groups come back in no guaranteed order. Rank them by adding `ORDER BY` on the aggregate — you can reference the alias:

```sql
SELECT country, COUNT(*) AS n_customers
FROM customers
GROUP BY country
ORDER BY n_customers DESC;
```

```text
╭────────────────┬─────────────╮
│    country     │ n_customers │
╞════════════════╪═════════════╡
│ Sweden         │         175 │
│ Germany        │         115 │
│ Denmark        │         101 │
│ Norway         │          98 │
│ United Kingdom │          69 │
│ Finland        │          65 │
│ Netherlands    │          64 │
│ France         │          51 │
│ Switzerland    │          31 │
│ Austria        │          31 │
╰────────────────┴─────────────╯
```

Sweden is the home market; the Nordics dominate. `ORDER BY n_customers DESC LIMIT 5` would give a top-5 — the standard "top-N" report shape (top-N *per group* needs window functions, Module 6).

### Grouping by multiple columns

List several columns in `GROUP BY` and you get one bucket per distinct **combination**. Finance wants payment volume broken down by method *and* outcome:

```sql
SELECT method, status, COUNT(*) AS n_payments, ROUND(SUM(amount), 2) AS total_amount
FROM payments
GROUP BY method, status
ORDER BY method, status;
```

```text
╭───────────────┬──────────┬────────────┬──────────────╮
│    method     │  status  │ n_payments │ total_amount │
╞═══════════════╪══════════╪════════════╪══════════════╡
│ bank_transfer │ captured │        626 │    351673.56 │
│ bank_transfer │ failed   │         41 │     27551.12 │
│ bank_transfer │ pending  │          5 │      2197.29 │
│ card          │ captured │       2458 │   1344662.51 │
│ card          │ failed   │        151 │     82946.73 │
│ card          │ pending  │         14 │      6085.11 │
│ klarna        │ captured │       1253 │    697029.07 │
│ klarna        │ failed   │         74 │     37404.31 │
│ klarna        │ pending  │          4 │      3471.39 │
│ paypal        │ captured │       1285 │    690906.75 │
│ paypal        │ failed   │         76 │      36919.2 │
│ paypal        │ pending  │          8 │      6022.97 │
│ refund        │ captured │        172 │    -88352.74 │
╰───────────────┴──────────┴────────────┴──────────────╯
```

13 rows, not 5 × 3 = 15: combinations that don't occur in the data (e.g. failed refunds) simply produce no bucket. Card is the dominant method; refunds appear as their own "method" with negative totals. This *long* format is precise but hard to scan — later in this module, conditional aggregation will pivot it into a wide table.

### Grouping by a key: per-order totals

The grouping column doesn't have to be a low-cardinality label. Grouping `order_items` by `order_id` computes each order's item revenue — using the canonical formula from `DATASET.md`. Which orders were our biggest baskets ever?

```sql
SELECT
  order_id,
  COUNT(*)      AS line_count,
  SUM(quantity) AS units,
  ROUND(SUM(quantity * unit_price * (1 - discount_pct / 100.0)), 2) AS item_revenue
FROM order_items
GROUP BY order_id
ORDER BY item_revenue DESC
LIMIT 5;
```

```text
╭──────────┬────────────┬───────┬──────────────╮
│ order_id │ line_count │ units │ item_revenue │
╞══════════╪════════════╪═══════╪══════════════╡
│     4718 │          6 │     9 │      4624.39 │
│     4249 │          4 │     7 │      4175.52 │
│      629 │          5 │    11 │      4125.17 │
│     2653 │          4 │     8 │      4086.37 │
│     1039 │          3 │     6 │      3973.96 │
╰──────────┴────────────┴───────┴──────────────╯
```

This is the building block of every revenue metric in this course. One caveat to keep you honest: `order_items` alone doesn't know each order's *status* — a fully canonical gross-revenue number must exclude cancelled orders, which requires joining to `orders`. Module 4 completes the picture; here we're computing per-order item revenue, which is correct as stated.

### The golden rule of GROUP BY

**Every column in the `SELECT` list must either be aggregated or appear in `GROUP BY`.** Why? After the split-apply-combine collapse, each output row represents a whole *bucket* of rows. For a grouped column there is exactly one value per bucket — fine. For any other column there are *many* candidate values, and SQL has no idea which one you mean.

Standard SQL (and PostgreSQL) rejects such queries outright. SQLite instead **silently picks one arbitrary row's value** — it runs, it returns numbers, and the numbers are meaningless. This is the most dangerous portability trap in this module, and Pitfall 1 below demonstrates it live. Until then, internalize the rule: *if it's not in GROUP BY, aggregate it.*

> **PostgreSQL note:** PostgreSQL raises `ERROR: column "..." must appear in the GROUP BY clause or be used in an aggregate function`. Treat that error as a friend — SQLite's silence is far worse.

## HAVING: filtering groups

`WHERE` filters **rows before grouping**. But some conditions can only be evaluated *after* aggregation — "products with at least 50 reviews" is a fact about a group, not about any single row. That's what `HAVING` is for: it filters buckets after the aggregates are computed.

The catalog team wants our most-reviewed products (social proof for the homepage), with their average rating:

```sql
SELECT product_id, COUNT(*) AS n_reviews, ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
GROUP BY product_id
HAVING COUNT(*) >= 50
ORDER BY avg_rating DESC;
```

```text
╭────────────┬───────────┬────────────╮
│ product_id │ n_reviews │ avg_rating │
╞════════════╪═══════════╪════════════╡
│        209 │        68 │       4.21 │
│        169 │        54 │       4.15 │
│          7 │        55 │       4.13 │
│        190 │        53 │       4.04 │
│        117 │        52 │        4.0 │
│        146 │        56 │       3.98 │
╰────────────┴───────────┴────────────╯
```

Six products cross the 50-review bar. Note the execution order: group → aggregate → `HAVING` throws away buckets → `ORDER BY` sorts survivors.

### WHERE and HAVING together

They're not rivals; real queries use both. Quality control asks: *among reviews written since 2025*, which products have enough recent reviews (≥ 8) to trust, but a worrying average (< 3.5)?

```sql
SELECT product_id, COUNT(*) AS reviews_since_2025, ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
WHERE created_at >= '2025-01-01'
GROUP BY product_id
HAVING COUNT(*) >= 8 AND AVG(rating) < 3.5
ORDER BY avg_rating;
```

```text
╭────────────┬────────────────────┬────────────╮
│ product_id │ reviews_since_2025 │ avg_rating │
╞════════════╪════════════════════╪════════════╡
│        220 │                 11 │        3.0 │
│        252 │                 11 │       3.18 │
│         44 │                  9 │       3.22 │
│         92 │                 10 │        3.4 │
│        148 │                  9 │       3.44 │
╰────────────┴────────────────────┴────────────╯
```

Read it as a pipeline: `WHERE` keeps only 2025+ reviews → `GROUP BY` buckets them per product → `HAVING` keeps only buckets that are both large enough and low-rated. Five products need attention. The division of labor is crisp: **row facts go in WHERE, group facts go in HAVING.** (`HAVING` can also combine multiple aggregate conditions with `AND`/`OR`, as here.)

## GROUP BY expressions: time buckets

You can group by any *expression*, not just a raw column. The workhorse for time series is `strftime('%Y-%m', ts)`, which buckets timestamps into calendar months (you met `strftime` in Module 2's date filtering).

Does the holiday season show in order volume? Second half of 2025:

```sql
SELECT strftime('%Y-%m', ordered_at) AS month, COUNT(*) AS n_orders
FROM orders
WHERE ordered_at >= '2025-07-01' AND ordered_at < '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬──────────╮
│  month  │ n_orders │
╞═════════╪══════════╡
│ 2025-07 │      188 │
│ 2025-08 │      158 │
│ 2025-09 │      173 │
│ 2025-10 │      171 │
│ 2025-11 │      295 │
│ 2025-12 │      447 │
╰─────────┴──────────╯
```

Emphatically yes: December runs at ~2.6× the autumn baseline. Two details: SQLite lets you reference the alias `month` in `GROUP BY` (so does PostgreSQL); and the `WHERE` uses a half-open range on the raw column, which is both correct and index-friendly (Module 10 explains why).

Money over time works the same way. Monthly **net cash** from captured payments in 2025 — the payments-side view of net revenue from the canonical definitions (refunds are negative, so plain `SUM` nets them out):

```sql
SELECT
  strftime('%Y-%m', paid_at)   AS month,
  printf('%,.2f', SUM(amount)) AS net_cash
FROM payments
WHERE status = 'captured'
  AND paid_at >= '2025-01-01' AND paid_at < '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬────────────╮
│  month  │  net_cash  │
╞═════════╪════════════╡
│ 2025-01 │ 34,698.64  │
│ 2025-02 │ 42,817.13  │
│ 2025-03 │ 53,140.59  │
│ 2025-04 │ 56,069.35  │
│ 2025-05 │ 69,196.13  │
│ 2025-06 │ 90,975.28  │
│ 2025-07 │ 94,999.21  │
│ 2025-08 │ 79,542.58  │
│ 2025-09 │ 97,492.86  │
│ 2025-10 │ 97,739.34  │
│ 2025-11 │ 149,344.75 │
│ 2025-12 │ 245,559.44 │
╰─────────┴────────────╯
```

Steady growth through the year, then the holiday spike: December alone brought in nearly a quarter million. (Item-revenue-based gross/net by month — the fully canonical version — needs the `orders` ⋈ `order_items` join from Module 4; the payments view is the correct single-table proxy.)

> **PostgreSQL note:** no `strftime` — use `to_char(paid_at, 'YYYY-MM')` for a label, or better `date_trunc('month', paid_at)` which returns a real timestamp that sorts and plots correctly.

## Conditional aggregation: CASE inside aggregates

Here is the technique that turns you from "can write GROUP BY" into "can build a report". Put a `CASE` expression *inside* an aggregate and you count or sum only the rows matching a condition — several different conditions side by side, in **one pass over the table**.

- `SUM(CASE WHEN cond THEN 1 ELSE 0 END)` — count of rows matching `cond`
- `SUM(CASE WHEN cond THEN amount ELSE 0 END)` — sum over matching rows
- `AVG(CASE WHEN cond THEN x END)` — average over matching rows only (no `ELSE` → NULL → skipped, using the NULL-ignoring rule from earlier *deliberately*)

Payments risk asks: which payment method fails most often?

```sql
SELECT
  method,
  COUNT(*) AS attempts,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed,
  ROUND(100.0 * SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_pct
FROM payments
WHERE method <> 'refund'
GROUP BY method
ORDER BY failure_pct DESC;
```

```text
╭───────────────┬──────────┬────────┬─────────────╮
│    method     │ attempts │ failed │ failure_pct │
╞═══════════════╪══════════╪════════╪═════════════╡
│ bank_transfer │      672 │     41 │         6.1 │
│ card          │     2623 │    151 │         5.8 │
│ paypal        │     1369 │     76 │         5.6 │
│ klarna        │     1331 │     74 │         5.6 │
╰───────────────┴──────────┴────────┴─────────────╯
```

Failure rates cluster around 5.5–6%, with bank transfers worst. Note the `100.0 *` — integer-division protection again — and that we excluded the `refund` pseudo-method, which isn't a payment attempt.

> **PostgreSQL note:** PostgreSQL (9.4+) has nicer syntax for exactly this: `COUNT(*) FILTER (WHERE status = 'failed')`. It's clearer and standard SQL — prefer it there. SQLite also supports `FILTER` on aggregates (3.30+), but the `CASE` form is universal and what you'll see in most codebases.

### Pivot-style reports

Stack several conditional aggregates and you've pivoted a long table into a wide one. Operations wants a monthly 2026 order-health dashboard — one row per month, statuses as columns:

```sql
SELECT
  strftime('%Y-%m', ordered_at) AS month,
  COUNT(*) AS orders,
  SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
  SUM(CASE WHEN status IN ('pending', 'paid', 'shipped') THEN 1 ELSE 0 END) AS in_flight,
  SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
  SUM(CASE WHEN status = 'returned'  THEN 1 ELSE 0 END) AS returned
FROM orders
WHERE ordered_at >= '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬────────┬───────────┬───────────┬───────────┬──────────╮
│  month  │ orders │ delivered │ in_flight │ cancelled │ returned │
╞═════════╪════════╪═══════════╪═══════════╪═══════════╪══════════╡
│ 2026-01 │    214 │       190 │         0 │        13 │       11 │
│ 2026-02 │    228 │       214 │         0 │        11 │        3 │
│ 2026-03 │    306 │       280 │         0 │        18 │        8 │
│ 2026-04 │    362 │       338 │         0 │        16 │        8 │
│ 2026-05 │    459 │       424 │         0 │        23 │       12 │
│ 2026-06 │    596 │       530 │        27 │        26 │       13 │
│ 2026-07 │    388 │        84 │       279 │        25 │        0 │
╰─────────┴────────┴───────────┴───────────┴───────────┴──────────╯
```

The shape tells an operational story: older months are fully settled (`in_flight` = 0), while July 2026 — the current month — has 279 orders still moving through the pipeline and no returns *yet*. When you see a metric "drop" in the most recent period, always ask whether the data has simply not finished arriving. This is called an *incomplete-period* or *maturation* effect, and conditional aggregation makes it visible instead of hiding it in an average.

One more pattern — a conditional `AVG` with no `ELSE`. Finance wants a yearly view: number of sales, the average sale amount (a payments-side proxy for AOV — a captured positive payment equals the order's total; the canonical order-items version arrives in Module 4), and total refunded:

```sql
SELECT
  strftime('%Y', paid_at) AS year,
  COUNT(CASE WHEN amount > 0 THEN 1 END)              AS sales,
  ROUND(AVG(CASE WHEN amount > 0 THEN amount END), 2) AS avg_sale_amount,
  ROUND(SUM(CASE WHEN amount < 0 THEN -amount ELSE 0 END), 2) AS refunded
FROM payments
WHERE status = 'captured'
GROUP BY year
ORDER BY year;
```

```text
╭──────┬───────┬─────────────────┬──────────╮
│ year │ sales │ avg_sale_amount │ refunded │
╞══════╪═══════╪═════════════════╪══════════╡
│ 2023 │   326 │          535.22 │  4591.73 │
│ 2024 │   907 │          521.28 │  15865.8 │
│ 2025 │  2031 │          562.32 │ 30491.97 │
│ 2026 │  2358 │          549.16 │ 37403.24 │
╰──────┴───────┴─────────────────┴──────────╯
```

The `CASE WHEN amount > 0 THEN amount END` has no `ELSE`, so refund rows become NULL and `AVG` skips them — the NULL-ignoring behavior working *for* you. Sales volume grows more than 6× from 2023 to 2025 while the average sale hovers around €520–560: growth is coming from more orders, not bigger baskets.

## Pitfalls

### Pitfall 1: SQLite's bare column in GROUP BY — silent garbage

An analyst wants each customer's order count *and their most recent order date*, and writes this:

```sql
-- BAD: ordered_at is neither aggregated nor in GROUP BY — SQLite picks an arbitrary row's value
SELECT customer_id, ordered_at, COUNT(*) AS n_orders
FROM orders
GROUP BY customer_id
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬─────────────────────┬──────────╮
│ customer_id │     ordered_at      │ n_orders │
╞═════════════╪═════════════════════╪══════════╡
│           2 │ 2024-03-16 20:06:46 │        2 │
│           3 │ 2026-06-06 22:33:01 │        4 │
│           4 │ 2025-12-20 07:18:37 │       13 │
│           5 │ 2024-06-26 10:56:00 │       13 │
│           6 │ 2026-06-02 02:56:36 │       29 │
╰─────────────┴─────────────────────┴──────────╯
```

It ran. It returned dates. Are they the latest orders? Let's put `MAX(ordered_at)` next to the bare column:

```sql
SELECT customer_id, ordered_at, MAX(ordered_at) AS true_latest, COUNT(*) AS n_orders
FROM orders
GROUP BY customer_id
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬─────────────────────┬─────────────────────┬──────────╮
│ customer_id │     ordered_at      │     true_latest     │ n_orders │
╞═════════════╪═════════════════════╪═════════════════════╪══════════╡
│           2 │ 2026-06-10 02:55:32 │ 2026-06-10 02:55:32 │        2 │
│           3 │ 2026-06-09 01:40:04 │ 2026-06-09 01:40:04 │        4 │
│           4 │ 2026-06-24 07:50:38 │ 2026-06-24 07:50:38 │       13 │
│           5 │ 2026-06-06 06:03:24 │ 2026-06-06 06:03:24 │       13 │
│           6 │ 2026-07-06 03:53:03 │ 2026-07-06 03:53:03 │       29 │
╰─────────────┴─────────────────────┴─────────────────────┴──────────╯
```

Two things to notice. First, the BAD query's dates were wrong: customer 2's real latest order is 2026-06-10, not 2024-03-16. Second — and this is how treacherous it is — **the bare `ordered_at` changed values between the two queries**. (SQLite has one documented exception: when the query contains exactly `MIN()` or `MAX()`, bare columns come from that min/max row, which is why the second query happens to line up. Change the aggregate mix and the values shift again.) The fix is to say what you mean:

```sql
SELECT customer_id, MAX(ordered_at) AS last_order, COUNT(*) AS n_orders
FROM orders
GROUP BY customer_id
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬─────────────────────┬──────────╮
│ customer_id │     last_order      │ n_orders │
╞═════════════╪═════════════════════╪══════════╡
│           2 │ 2026-06-10 02:55:32 │        2 │
│           3 │ 2026-06-09 01:40:04 │        4 │
│           4 │ 2026-06-24 07:50:38 │       13 │
│           5 │ 2026-06-06 06:03:24 │       13 │
│           6 │ 2026-07-06 03:53:03 │       29 │
╰─────────────┴─────────────────────┴──────────╯
```

> **PostgreSQL note:** the BAD query doesn't run at all in PostgreSQL: `ERROR: column "orders.ordered_at" must appear in the GROUP BY clause or be used in an aggregate function`. Write SQLite queries as if that error existed — your SQL stays correct *and* portable.

### Pitfall 2: COUNT(col) undercounts because of NULLs

"How many clickstream events did we log?" Someone counts the column they happen to think of:

```sql
-- BAD: product_id is NULL for search and begin_checkout events — they vanish from the count
SELECT COUNT(product_id) AS n_events
FROM events;
```

```text
╭──────────╮
│ n_events │
╞══════════╡
│    14927 │
╰──────────╯
```

Looks plausible — and is wrong. `COUNT(product_id)` counted only events that *reference a product*; searches and checkout-starts have `product_id` NULL and were silently dropped. The fix — and the habit: **count rows with `COUNT(*)`; count a column only when you specifically mean "non-NULL values of this column"**:

```sql
SELECT
  COUNT(*)          AS n_events,
  COUNT(product_id) AS events_with_product
FROM events;
```

```text
╭──────────┬─────────────────────╮
│ n_events │ events_with_product │
╞══════════╪═════════════════════╡
│    16364 │               14927 │
╰──────────┴─────────────────────╯
```

The BAD query undercounted by 1,437 events — about 9% of all traffic, gone without a warning.

### Pitfall 3: AVG over NULLs vs COALESCE — two different business answers

About 35% of reviews are rating-only (`review_text` is NULL). The content team asks: *"How much review text does the average review contribute?"* — they're sizing a text-analysis job over **all** reviews, so a rating-only review should count as 0 characters.

```sql
-- BAD: AVG skips NULL review_text, so this averages only over reviews that have text
SELECT ROUND(AVG(LENGTH(review_text)), 1) AS avg_chars
FROM reviews;
```

```text
╭───────────╮
│ avg_chars │
╞═══════════╡
│      43.9 │
╰───────────╯
```

43.9 answers a *different* question ("how long is a typical *written* review?"). For the question actually asked, NULL must become 0 before averaging:

```sql
SELECT
  ROUND(AVG(LENGTH(review_text)), 1)              AS avg_chars_written_only,
  ROUND(AVG(COALESCE(LENGTH(review_text), 0)), 1) AS avg_chars_all_reviews
FROM reviews;
```

```text
╭────────────────────────┬───────────────────────╮
│ avg_chars_written_only │ avg_chars_all_reviews │
╞════════════════════════╪═══════════════════════╡
│                   43.9 │                  28.7 │
╰────────────────────────┴───────────────────────╯
```

43.9 vs 28.7 — a 53% difference from one `COALESCE`. Neither number is universally "correct"; the *question* decides. Whenever you `AVG` a nullable column, stop and ask: should missing mean "excluded" or "zero"? Then encode that decision explicitly, so the next reader sees it too.

### Pitfall 4: HAVING doing WHERE's job

You want monthly order counts for 2026. This works:

```sql
-- BAD: filters months after grouping the entire 3.5-year table — WHERE's job done late
SELECT strftime('%Y-%m', ordered_at) AS month, COUNT(*) AS n_orders
FROM orders
GROUP BY month
HAVING month >= '2026-01'
ORDER BY month;
```

```text
╭─────────┬──────────╮
│  month  │ n_orders │
╞═════════╪══════════╡
│ 2026-01 │      214 │
│ 2026-02 │      228 │
│ 2026-03 │      306 │
│ 2026-04 │      362 │
│ 2026-05 │      459 │
│ 2026-06 │      596 │
│ 2026-07 │      388 │
╰─────────┴──────────╯
```

Right answer, wrong query. The engine grouped and counted **all 6,000 orders across 43 months**, then threw away 36 of the 43 result rows. `HAVING` runs *after* aggregation; a condition that doesn't involve an aggregate belongs in `WHERE`, where it prunes rows *before* the expensive work (and before any index-unfriendly `strftime` on every row — Module 10 revisits this):

```sql
SELECT strftime('%Y-%m', ordered_at) AS month, COUNT(*) AS n_orders
FROM orders
WHERE ordered_at >= '2026-01-01'
GROUP BY month
ORDER BY month;
```

```text
╭─────────┬──────────╮
│  month  │ n_orders │
╞═════════╪══════════╡
│ 2026-01 │      214 │
│ 2026-02 │      228 │
│ 2026-03 │      306 │
│ 2026-04 │      362 │
│ 2026-05 │      459 │
│ 2026-06 │      596 │
│ 2026-07 │      388 │
╰─────────┴──────────╯
```

Identical output, fraction of the work. On 6,000 rows nobody notices; on 600 million rows, the difference is your job. The rule from earlier bears repeating because misuse *usually still returns correct results*, which is exactly why it survives code review: **row conditions → WHERE, aggregate conditions → HAVING.** (Beware also that in SQLite a non-aggregate, non-grouped column inside `HAVING` triggers the same bare-column roulette as Pitfall 1.)

## Exercises

Answer each with a single query against `shop.db`. Use only material from Modules 1–3. Revenue and AOV questions use the canonical definitions from `DATASET.md`.

**Warm-up**

1. Catalog snapshot for the ops dashboard: in one row, how many products does Nordkart list, how many are still active, how many are discontinued, and how many distinct suppliers does the catalog draw on? (Hint: `is_active` is 0/1 — what does `SUM` of it mean?)
2. Show the order pipeline: how many orders are in each status, most common status first?
3. Which are our top 5 countries by number of customer accounts?

**Core**

4. Marketing is planning 2027 inventory. Produce monthly order counts for all of 2025 (12 rows, chronological). In which months should the warehouse staff up?
5. How trustworthy are our star ratings? For each rating value 1–5, show the number of reviews and the percentage of those reviews that include written text. Do angry customers write more?
6. Is payment reliability improving? For each year, show total payment attempts (exclude the `refund` method), how many failed, and the failure rate as a percentage.
7. Logistics wants a carrier scorecard: per carrier, the number of shipments handled, how many are still in transit, and the average days from shipping to delivery — fastest carrier first.
8. Merchandising asks for the all-time top 10 products by total item revenue (canonical formula), with total units sold. (Product IDs are fine — names need Module 4's joins.)
9. Where is our marketing consent strongest? For countries with at least 60 customers, show the customer count and the marketing opt-in rate as a percentage, highest rate first.

**Challenge**

10. Pricing review: for each category (`category_id`), across **active** products only, show how many products it has and the average margin percentage, where a product's margin percentage is `100 * (unit_price - unit_cost) / unit_price`. Order by average margin, best first. Which categories look most and least profitable?
11. Build a yearly order-health report: per year — total orders, cancelled count, returned count, cancellation rate (%), and return rate (%). Is the cancellation rate trending the right way? Any caveat about the 2026 return rate?
12. The CFO wants a 2026 monthly finance summary from captured payments: number of sales (positive payments), gross inflow, total refunded (as a positive number), net cash, and the average sale amount (our payments-side AOV proxy). One row per month.

## Key takeaways

- **Aggregates collapse rows**: without `GROUP BY`, the table is one group → one output row; with `GROUP BY`, one output row per distinct group value.
- **COUNT three ways**: `COUNT(*)` = rows; `COUNT(col)` = non-NULL values; `COUNT(DISTINCT col)` = unique non-NULL values. Default to `COUNT(*)` for "how many".
- **Aggregates skip NULL** (all except `COUNT(*)`). Hence `AVG(col)` ≠ `SUM(col)/COUNT(*)` when NULLs exist. Decide explicitly: NULL = "exclude" (leave it) or NULL = "zero" (`COALESCE(col, 0)`).
- **Empty set**: `COUNT` → 0; `SUM`/`AVG`/`MIN`/`MAX` → NULL. Wrap with `COALESCE` if a number is required.
- **Golden rule**: every selected non-aggregate column goes in `GROUP BY`. SQLite won't enforce it and returns arbitrary values; PostgreSQL errors. Write as if the error existed.
- **WHERE vs HAVING**: `WHERE` filters rows *before* grouping; `HAVING` filters groups *after* aggregation. Non-aggregate conditions belong in `WHERE` — correct semantics and less work.
- **Logical order**: `FROM` → `WHERE` → `GROUP BY` → aggregates → `HAVING` → `SELECT` → `ORDER BY` → `LIMIT`.
- **Group by expressions**: `GROUP BY strftime('%Y-%m', ts)` for monthly buckets (PostgreSQL: `date_trunc('month', ts)`).
- **Conditional aggregation**: `SUM(CASE WHEN cond THEN 1 ELSE 0 END)` counts matches; `AVG(CASE WHEN cond THEN x END)` (no `ELSE`) averages a subset; stack several for pivot-style reports. PostgreSQL/SQLite alternative: `agg(...) FILTER (WHERE cond)`.
- **Integer division truncates**: `discount_pct / 100` = 0. Use `100.0`.
- **Money display**: compute with numbers, `ROUND(x, 2)` for output, `printf('%,.2f', x)` (text!) only at the presentation edge.
- **Nordkart specifics**: refunds are negative payment amounts (plain `SUM` = net); cancelled orders must be excluded from gross revenue; the current period is always incomplete — read recent months with suspicion.
