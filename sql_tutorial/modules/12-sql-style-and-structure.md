# Module 12 — SQL Style & Structure

You can now write joins, window functions, recursive CTEs, and point-in-time logic — the hard technical skills are behind you. What separates a competent query-writer from a professional data engineer is everything around the query: whether a colleague can read it, whether its correctness is *tested* rather than assumed, and whether it survives six months of edits without rotting. SQL has no compiler to catch a wrong join and no type system to catch a wrong grain — discipline and tooling have to fill that gap. This module is that discipline, written down.

## What you'll learn

- A concrete, opinionated SQL style guide: keyword case, identifier case, one clause per line, join and CTE indentation, comma placement — and the reasoning behind each rule
- Naming conventions that scale: plural tables, `table_id` keys, `is_`/`has_` booleans, `v_`/`stg_` prefixes, and which words to never use as identifiers
- Query **grain** — what one output row means — and why every non-trivial query should state it
- Header comments (purpose, grain, definitions) versus inline comments (WHY, never WHAT)
- The dbt-style **CTE pipeline architecture**: import CTEs → logical CTEs → final SELECT, demonstrated by refactoring a Module 11-style cohort query
- Testing SQL with **assertion queries**: uniqueness, grain, referential integrity, accepted values, and freshness checks — plus a working test runner (`tests/run_tests.sh`) that ships with this course
- A code-review checklist for SQL, and how a reconciliation test catches a fan-out bug that eyeballing never will
- Performance-aware habits (Module 10 distilled into reflexes)
- When *not* to use SQL
- The database ecosystem map: SQLite, PostgreSQL, MySQL, DuckDB, the cloud warehouses, dbt, and orchestrators
- Appendix: the complete PostgreSQL migration cheatsheet for everything in this course

All queries in this module are read-only, so everything runs against `shop.db` from the course root. (Exercise 10 asks you to *break* a database — you'll do that on a copy under `/tmp`, never on `shop.db`.)

## 1. The style guide

Style arguments feel petty until you maintain a 400-line query written by someone who lost every one of them. The point of a style guide is not that these choices are objectively best — several are coin flips — it's that a codebase that picks *one* answer per question becomes skimmable. You stop parsing text and start recognizing shapes.

Here is the guide this course has silently followed for eleven modules, now made explicit:

1. **Keywords UPPERCASE, identifiers lowercase.** `SELECT`, `FROM`, `LEFT JOIN` in caps; `orders`, `gross_revenue` in `snake_case`. The lowercase-keywords camp (common in dbt shops, where editors highlight keywords anyway) is legitimate — but mixed-case identifiers are not, because SQL identifiers are case-insensitive and PostgreSQL folds unquoted identifiers to lowercase. We recommend uppercase keywords: SQL reads as interleaved *structure* (clauses) and *content* (your names), and case contrast makes the structure visible even in un-highlighted contexts — logs, diffs, error messages, code review.
2. **One clause per line.** `SELECT`, `FROM`, each `JOIN`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT` each start a new line. A query's shape should be its outline.
3. **One select-list item per line** once there are more than two or three, aligned one indent level under `SELECT`.
4. **Trailing commas** (comma at the end of each line, none after the last item). The leading-comma style (`, revenue`) exists to make single-line diffs when appending items and to prevent the classic missing-comma bug; it's a defensible choice, but it fights how every other language punctuates. Pick trailing and be consistent.
5. **Each `JOIN` on its own line, its `ON` condition on the same line** (or indented on the next line when long). Write the joined table's column first: `JOIN orders AS o ON o.order_id = oi.order_id` — you can verify the join key by reading only that line.
6. **Always alias tables, and always with `AS`.** Short but meaningful aliases: `o` for `orders`, `oi` for `order_items`. Never alias `orders` to `a` — single letters divorced from the table name force the reader to keep a lookup table in their head.
7. **Name every computed column.** `ROUND(SUM(...), 2) AS gross_revenue`, never an anonymous expression column.
8. **Never `SELECT *` in saved/production SQL.** Fine while exploring; in anything committed, it hides schema drift, breaks when columns are added, and silently drags wide columns through the query. (Module 10: it also defeats covering indexes.)
9. **No ordinals in `GROUP BY` / `ORDER BY`** (`GROUP BY 1` breaks silently when someone reorders the select list). Exception: nobody will fault `ORDER BY 1` in a throwaway console query.
10. **Indent CTE bodies one level**; the CTE name and `AS (` sit at margin, the closing `)` returns to margin. Blank line between CTEs.
11. **Filters vertically**: `WHERE` on its own line, each `AND` aligned beneath it.
12. **Half-open date ranges** (`>= start AND < end`), always — Module 2's rule, restated because style reviews are where you enforce it.

> **PostgreSQL note:** lowercase `snake_case` identifiers aren't just taste there — PostgreSQL folds unquoted identifiers to lowercase, so `SELECT x AS totalRevenue` comes back as `totalrevenue` unless you quote it, and quoted `"CamelCase"` names then require quotes *forever*. Lowercase everything and the problem cannot exist.

### Before and after

Here is a real query — Module 6's percent-of-total pattern answering "which five categories carried 2025?" — the way it too often arrives in a code review. It is *correct*. Run it:

```sql
-- BAD: works, but unreadable — implicit comma joins, single-line, cryptic
-- aliases, GROUP BY ordinal, the revenue formula pasted three times
select c.name, round(sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100.0)),2) rev, round(100.0*sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100.0))/sum(sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100.0))) over(),1) pct from order_items oi, orders o, products p, categories c where oi.order_id=o.order_id and p.product_id=oi.product_id and c.category_id=p.category_id and o.status<>'cancelled' and o.ordered_at>='2025-01-01' and o.ordered_at<'2026-01-01' group by 1 order by 2 desc limit 5;
```

```text
╭──────────────────┬───────────┬──────╮
│       name       │    rev    │ pct  │
╞══════════════════╪═══════════╪══════╡
│ Tents            │ 213775.07 │ 18.9 │
│ Avalanche Safety │ 164086.04 │ 14.5 │
│ Kayaks           │ 149161.64 │ 13.2 │
│ Skis             │ 129683.33 │ 11.5 │
│ Hiking Boots     │  73513.29 │  6.5 │
╰──────────────────┴───────────┴──────╯
```

Now the same logic under the style guide. A CTE computes item revenue *once*, joins are explicit, every column is named, and each clause sits on its own line:

```sql
WITH item_revenue AS (
    SELECT
        p.category_id,
        oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) AS revenue
    FROM order_items AS oi
    JOIN orders    AS o ON o.order_id = oi.order_id
    JOIN products  AS p ON p.product_id = oi.product_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
)
SELECT
    c.name                                                        AS category,
    ROUND(SUM(ir.revenue), 2)                                     AS gross_revenue,
    ROUND(100.0 * SUM(ir.revenue) / SUM(SUM(ir.revenue)) OVER (), 1) AS pct_of_total
FROM item_revenue AS ir
JOIN categories   AS c ON c.category_id = ir.category_id
GROUP BY c.name
ORDER BY gross_revenue DESC
LIMIT 5;
```

```text
╭──────────────────┬───────────────┬──────────────╮
│     category     │ gross_revenue │ pct_of_total │
╞══════════════════╪═══════════════╪══════════════╡
│ Tents            │     213775.07 │         18.9 │
│ Avalanche Safety │     164086.04 │         14.5 │
│ Kayaks           │     149161.64 │         13.2 │
│ Skis             │     129683.33 │         11.5 │
│ Hiking Boots     │      73513.29 │          6.5 │
╰──────────────────┴───────────────┴──────────────╯
```

Same values, and now the query answers questions *about itself*: What population? (non-cancelled 2025 orders — read the `WHERE`.) What's the metric? (item revenue, defined once, named.) Is `pct_of_total` the share of the top 5 or of everything? The window runs before `LIMIT` (Module 6), so it's the share of *all* categories — and with the query readable, a reviewer can actually spot that subtlety and confirm it's intended.

The reformat cost three minutes. Every future reader saves ten.

## 2. Naming things

Names are the one part of your SQL that appears in *everyone else's* SQL. Conventions:

- **Tables: plural nouns** — `customers`, `orders`. The singular camp ("each row is *a* customer") has real arguments, and either works — **pick a lane per codebase and never mix**. Nordkart's schema is plural; when extending it, plural it is. Mixing (`customer`, `orders`) is the only wrong answer.
- **Primary keys: `table_id`, not `id`.** `customers.customer_id` is deliberate: the foreign key in `orders` is *also* `customer_id`, so join conditions read as tautologies (`o.customer_id = c.customer_id`), `USING (customer_id)` works, and a bare `customer_id` in a 6-table query is unambiguous. Bare `id` looks tidy on one table and turns into `orders.id = ...` guesswork everywhere else.
- **Booleans: `is_` / `has_` prefixes** — `is_active`, `is_default`, `has_shipped`. The name should read as a predicate; `active` could be a status string, a date, anything. (Nordkart's `marketing_opt_in` predates this rule — real schemas always carry a few fossils. Don't churn names without a migration plan; do better on new columns.)
- **Avoid reserved words and near-reserved traps**: `order`, `user`, `group`, `desc`, `default`, `check`, `index`, `column`. SQLite will often let you quote your way through (`"order"`); you'll pay the quoting tax on every reference, in every dialect, forever. This is why the table is `orders` and the timestamp is `ordered_at`, not `date`.
- **Timestamps: `_at` suffix; dates: `_date`; both past-tense verbs** — `created_at`, `shipped_at`, `delivered_at`.
- **Views: `v_` prefix** (`v_order_totals`), so readers know they're querying logic, not storage (Module 8). **Staging tables: `stg_` prefix** (`stg_orders_raw`) for load-pipeline intermediates (Module 9). Warehouse folk add `int_` (intermediate), `fct_`/`dim_` (star-schema fact and dimension tables, Module 7); adopt those the moment your project grows layers.

A naming convention is testable — the schema catalog is just a table. Audit Nordkart:

```sql
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;
```

```text
╭───────────────╮
│     name      │
╞═══════════════╡
│ addresses     │
│ categories    │
│ customers     │
│ events        │
│ order_items   │
│ orders        │
│ payments      │
│ price_history │
│ products      │
│ reviews       │
│ shipments     │
│ suppliers     │
╰───────────────╯
```

Twelve tables, all plural, all lowercase, no reserved words. (The `sqlite_%` filter hides internal bookkeeping like the `sqlite_stat1` table that `ANALYZE` created in Module 10.)

> **PostgreSQL note:** the catalog query there is `SELECT tablename FROM pg_tables WHERE schemaname = 'public'`, or the standard `information_schema.tables`, which SQLite lacks. Same auditing idea.

## 3. Comments and query grain

The single highest-value line of documentation a query can carry is its **grain**: what one output row represents. "One row per customer per calendar month with at least one non-cancelled order" tells a reader what they can safely join this result to, what `COUNT(*)` counts, and whether averaging a column is meaningful. Half the bugs in this course's pitfall sections — join fan-out, wrong-level averages, double counting — are, at root, *grain* mistakes. Write the grain down and they become visible.

A production query deserves a short header block:

```text
-- =====================================================================
-- Report:  <one-line purpose>
-- Grain:   one row per <entity / entity+period>
-- Notes:   <metric definitions used, populations excluded, gotchas>
-- Author:  <who to ask>          Updated: <when, and why if surprising>
-- =====================================================================
```

Inline comments are for **WHY, never WHAT**. `-- join to orders` above a join to orders is noise that will drift out of date; `-- cancelled never counts as revenue` earns its line because it records a *business decision* the SQL alone can't justify. Delete any comment that merely narrates the syntax.

Here's the full discipline applied to a real question — how is 2026 tracking, month by month?

```sql
-- Monthly gross revenue, 2026 year-to-date.
-- Grain: one row per calendar month (2026-01 .. 2026-07).
-- Gross revenue = item revenue of non-cancelled orders placed in the month
-- (canonical definition, DATASET.md); returned orders count, refunds ignored.
SELECT
    strftime('%Y-%m', o.ordered_at)  AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'          -- cancelled never counts as revenue
  AND o.ordered_at >= '2026-01-01'     -- half-open range: index-friendly,
  AND o.ordered_at <  '2027-01-01'     -- no fencepost errors (Module 2)
GROUP BY order_month
ORDER BY order_month;
```

```text
╭─────────────┬───────────────╮
│ order_month │ gross_revenue │
╞═════════════╪═══════════════╡
│ 2026-01     │     128438.46 │
│ 2026-02     │     118340.17 │
│ 2026-03     │     170011.09 │
│ 2026-04     │     194769.61 │
│ 2026-05     │     234748.78 │
│ 2026-06     │     288614.97 │
│ 2026-07     │     181073.95 │
╰─────────────┴───────────────╯
```

Every comment here answers a question the SQL can't: which canonical definition, why `<>` `'cancelled'`, why half-open. Note also what the header does for the *reader of the output*: July looks like a crash until the grain note reminds you the data ends July 14.

## 4. CTE pipeline architecture

Module 5 taught `WITH` as syntax. This section is about `WITH` as *architecture* — the pattern that tools like dbt turned into an industry standard. A well-structured analytical query has three layers:

1. **Import CTEs** — one per source table. They only *select the needed columns, apply base filters, and rename awkward fields*. No joins, no aggregation. They're the query's "imports section": the full list of what this query touches, at the top.
2. **Logical CTEs** — the transformations, **one idea per CTE**, each building on previous ones. Each has a name that states what it *is* (`first_order_month`, not `temp2`), and a knowable grain.
3. **Final SELECT** — presentation only: pick columns, compute display ratios, `ROUND`, `ORDER BY`. If the final SELECT contains a business rule, a layer above is missing.

The payoff is debuggability: any CTE can be run alone (`SELECT * FROM ... LIMIT 20` mentally substituting the pipeline above it), so you can bisect a wrong number layer by layer instead of re-deriving a monolith.

Here's the worked example — the Module 11 cohort-retention analysis ("of the customers whose first order was in month X, how many came back?") as a monolith. It is correct. It is also the kind of query that gets a name like `retention_final_v3_FIXED.sql`:

```sql
-- BAD: correct output, unmaintainable shape — the cohort derivation is
-- pasted twice more as correlated subqueries, and the month arithmetic
-- appears twice because nothing can be named
SELECT f.cohort_month, (CAST(substr(a.order_month,1,4) AS INTEGER)-CAST(substr(f.cohort_month,1,4) AS INTEGER))*12+(CAST(substr(a.order_month,6,2) AS INTEGER)-CAST(substr(f.cohort_month,6,2) AS INTEGER)) AS months_since, COUNT(DISTINCT a.customer_id) AS active_customers, (SELECT COUNT(*) FROM (SELECT customer_id, MIN(strftime('%Y-%m', ordered_at)) AS m FROM orders WHERE status<>'cancelled' GROUP BY customer_id) x WHERE x.m=f.cohort_month) AS cohort_size, ROUND(100.0*COUNT(DISTINCT a.customer_id)/(SELECT COUNT(*) FROM (SELECT customer_id, MIN(strftime('%Y-%m', ordered_at)) AS m FROM orders WHERE status<>'cancelled' GROUP BY customer_id) x WHERE x.m=f.cohort_month),1) AS retention_pct FROM (SELECT customer_id, MIN(strftime('%Y-%m', ordered_at)) AS cohort_month FROM orders WHERE status<>'cancelled' GROUP BY customer_id) f JOIN (SELECT DISTINCT customer_id, strftime('%Y-%m', ordered_at) AS order_month FROM orders WHERE status<>'cancelled') a ON a.customer_id=f.customer_id WHERE f.cohort_month>='2025-01' AND f.cohort_month<='2025-06' AND (CAST(substr(a.order_month,1,4) AS INTEGER)-CAST(substr(f.cohort_month,1,4) AS INTEGER))*12+(CAST(substr(a.order_month,6,2) AS INTEGER)-CAST(substr(f.cohort_month,6,2) AS INTEGER)) BETWEEN 0 AND 3 GROUP BY 1,2 ORDER BY 1,2;
```

```text
╭──────────────┬──────────────┬──────────────────┬─────────────┬───────────────╮
│ cohort_month │ months_since │ active_customers │ cohort_size │ retention_pct │
╞══════════════╪══════════════╪══════════════════╪═════════════╪═══════════════╡
│ 2025-01      │            0 │                5 │           5 │         100.0 │
│ 2025-02      │            0 │               11 │          11 │         100.0 │
│ 2025-02      │            1 │                1 │          11 │           9.1 │
│ 2025-02      │            3 │                1 │          11 │           9.1 │
╰──────────────┴──────────────┴──────────────────┴─────────────┴───────────────╯
... 20 rows total (output identical to the refactor below)
```

Same query, layered:

```sql
-- Cohort retention, monthly cohorts Jan-Jun 2025, months 0-3.
-- Grain: one row per (cohort_month, months_since).
-- Cohort = month of a customer's first non-cancelled order.
-- Retained = placed a non-cancelled order in that later month
-- ("active customer", canonical definition).
WITH
-- ============ import layer: source rows, minimally shaped ============
non_cancelled_orders AS (
    SELECT
        customer_id,
        strftime('%Y-%m', ordered_at) AS order_month
    FROM orders
    WHERE status <> 'cancelled'
),

-- ============ logical layer: one idea per CTE ============
first_order_month AS (         -- each customer's cohort
    SELECT
        customer_id,
        MIN(order_month) AS cohort_month
    FROM non_cancelled_orders
    GROUP BY customer_id
),

cohort_sizes AS (              -- denominator for retention %
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM first_order_month
    GROUP BY cohort_month
),

customer_activity AS (         -- one row per customer per active month
    SELECT DISTINCT
        f.cohort_month,
        (CAST(substr(o.order_month, 1, 4) AS INTEGER)
         - CAST(substr(f.cohort_month, 1, 4) AS INTEGER)) * 12
        + (CAST(substr(o.order_month, 6, 2) AS INTEGER)
           - CAST(substr(f.cohort_month, 6, 2) AS INTEGER)) AS months_since,
        o.customer_id
    FROM non_cancelled_orders AS o
    JOIN first_order_month    AS f ON f.customer_id = o.customer_id
),

retention AS (                 -- collapse to the target grain
    SELECT
        cohort_month,
        months_since,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, months_since
)

-- ============ final SELECT: presentation only ============
SELECT
    r.cohort_month,
    r.months_since,
    r.active_customers,
    s.cohort_size,
    ROUND(100.0 * r.active_customers / s.cohort_size, 1) AS retention_pct
FROM retention AS r
JOIN cohort_sizes AS s ON s.cohort_month = r.cohort_month
WHERE r.cohort_month BETWEEN '2025-01' AND '2025-06'
  AND r.months_since BETWEEN 0 AND 3
ORDER BY r.cohort_month, r.months_since;
```

```text
╭──────────────┬──────────────┬──────────────────┬─────────────┬───────────────╮
│ cohort_month │ months_since │ active_customers │ cohort_size │ retention_pct │
╞══════════════╪══════════════╪══════════════════╪═════════════╪═══════════════╡
│ 2025-01      │            0 │                5 │           5 │         100.0 │
│ 2025-02      │            0 │               11 │          11 │         100.0 │
│ 2025-02      │            1 │                1 │          11 │           9.1 │
│ 2025-02      │            3 │                1 │          11 │           9.1 │
│ 2025-03      │            0 │               11 │          11 │         100.0 │
│ 2025-03      │            1 │                4 │          11 │          36.4 │
│ 2025-03      │            2 │                1 │          11 │           9.1 │
│ 2025-03      │            3 │                5 │          11 │          45.5 │
│ 2025-04      │            0 │               18 │          18 │         100.0 │
│ 2025-04      │            1 │                3 │          18 │          16.7 │
│ 2025-04      │            2 │                4 │          18 │          22.2 │
│ 2025-04      │            3 │                2 │          18 │          11.1 │
│ 2025-05      │            0 │               19 │          19 │         100.0 │
│ 2025-05      │            1 │                8 │          19 │          42.1 │
│ 2025-05      │            2 │                7 │          19 │          36.8 │
│ 2025-05      │            3 │               10 │          19 │          52.6 │
│ 2025-06      │            0 │               13 │          13 │         100.0 │
│ 2025-06      │            1 │                5 │          13 │          38.5 │
│ 2025-06      │            2 │                4 │          13 │          30.8 │
│ 2025-06      │            3 │                4 │          13 │          30.8 │
╰──────────────┴──────────────┴──────────────────┴─────────────┴───────────────╯
```

Byte-for-byte the same 20 rows. But now: the "non-cancelled" rule exists in exactly one place; each CTE's comment states its grain; the month arithmetic lives in one CTE instead of two spots; and when someone asks "why does the 2025-01 cohort show only month 0?" you can run `first_order_month` alone and see that only 5 customers started in January — a cohort so small that nobody happened to return within 3 months. (Missing combinations produce *no row*, not a zero row — to display zeros you'd cross-join a scaffold, Module 4's trick.)

This is also, almost exactly, how a dbt project is organized — except each CTE would be its own file (a "model"), materialized as a view or table, tested and reusable across reports. Learn the layered-CTE shape and you've learned dbt's mental model for free.

> **PostgreSQL note:** identical syntax. One planning nuance from Module 5 applies: PostgreSQL 12+ inlines CTEs like SQLite does, and `AS MATERIALIZED` forces the old always-materialize behavior when you want a CTE computed exactly once.

## 5. Testing SQL with assertion queries

Application code gets unit tests; SQL usually gets "the numbers looked plausible." Fix that with **assertion queries**: a query that `SELECT`s *rows violating an invariant*. The convention:

> **Zero rows returned = the test passes.** Any row returned = a failure, and the rows themselves are the diagnostic.

While *exploring*, you'd count violations — "are there duplicate reviews per (product, customer)?":

```sql
SELECT COUNT(*) AS duplicate_pairs
FROM (
    SELECT product_id, customer_id
    FROM reviews
    GROUP BY product_id, customer_id
    HAVING COUNT(*) > 1
);
```

```text
╭─────────────────╮
│ duplicate_pairs │
╞═════════════════╡
│               0 │
╰─────────────────╯
```

The *test* form drops the count wrapper and returns the offending rows directly — a passing test is silent, a failing one shows you exactly which rows to investigate:

```sql
SELECT product_id, customer_id, COUNT(*) AS n_rows
FROM reviews
GROUP BY product_id, customer_id
HAVING COUNT(*) > 1;
```

```text
(zero rows returned — the invariant holds, the test passes)
```

Five families of assertion cover most of what goes wrong in practice. This course ships a working suite in `tests/` — one file per invariant. The files:

**Uniqueness** — `tests/test_customers_email_unique.sql`:

```sql
-- Test: customers.email is unique.
-- A row returned = a duplicated email = FAIL.
SELECT email, COUNT(*) AS n_rows
FROM customers
GROUP BY email
HAVING COUNT(*) > 1;
```

```text
(zero rows returned — pass)
```

**Grain** — `tests/test_order_items_grain.sql`. This is the uniqueness pattern applied to a *composite* key, and it's the single most valuable test in the suite: every revenue number in this course silently assumes it.

```sql
-- Test: order_items has exactly one row per (order_id, product_id).
-- Guards every revenue query in the course against silent double-counting.
SELECT order_id, product_id, COUNT(*) AS n_rows
FROM order_items
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;
```

```text
(zero rows returned — pass)
```

**Referential integrity** — `tests/test_orders_valid_customer.sql`, the Module 4 anti-join as a guard:

```sql
-- Test: every order references an existing customer (referential integrity).
-- SQLite only enforces FKs when PRAGMA foreign_keys = ON, so we verify.
SELECT o.order_id, o.customer_id
FROM orders AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM customers AS c
    WHERE c.customer_id = o.customer_id
);
```

```text
(zero rows returned — pass)
```

**Accepted values** — `tests/test_orders_status_values.sql`. Upstream systems grow new enum values without telling you; better a red test than a report where a new `'refunded'` status slips through every `status <> 'cancelled'` filter unclassified:

```sql
-- Test: orders.status takes only the six documented values.
-- A new status appearing upstream should break loudly, not corrupt reports.
SELECT DISTINCT status
FROM orders
WHERE status NOT IN
    ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned');
```

```text
(zero rows returned — pass)
```

**Business-rule / structural** — `tests/test_addresses_one_default.sql`. Not a key, not an FK — a rule the application relies on:

```sql
-- Test: every customer who has addresses has exactly one default address.
-- Checkout picks "the default" — two defaults or zero would break it.
SELECT customer_id, SUM(is_default) AS n_defaults
FROM addresses
GROUP BY customer_id
HAVING SUM(is_default) <> 1;
```

```text
(zero rows returned — pass)
```

**Freshness** — `tests/test_orders_freshness.sql`. A pipeline that silently stopped loading three days ago passes every test above; this one catches it:

```sql
-- Test: the orders table is fresh (newest order on/after 2026-07-01).
-- Against a live database you would use a rolling window instead:
--     HAVING MAX(ordered_at) < datetime('now', '-2 days')
-- The course dataset is frozen at 2026-07-14, so we pin the threshold.
SELECT MAX(ordered_at) AS newest_order
FROM orders
HAVING MAX(ordered_at) < '2026-07-01';
```

```text
(zero rows returned — pass)
```

(`HAVING` without `GROUP BY` treats the whole table as one group — the aggregate row is emitted only if the condition holds, which makes it a tidy one-row assertion.)

### The test runner

The zero-rows convention makes automation trivial: run every file, count output lines, fail loudly on any output. `tests/run_tests.sh` (in the course repo):

```bash
#!/usr/bin/env bash
# Assertion-test runner for the Nordkart database.
#
# Convention: every tests/test_*.sql file SELECTs rows that VIOLATE an
# invariant. Zero rows returned = PASS. Any row returned = FAIL, and the
# violating rows are printed so the failure is immediately diagnosable.
#
# Usage (from the course root):
#     bash tests/run_tests.sh            # runs against shop.db
#     bash tests/run_tests.sh other.db   # runs against another database
# Exits 0 when every test passes, 1 otherwise.

set -u
db="${1:-shop.db}"
fail=0

for f in tests/test_*.sql; do
    rows=$(sqlite3 "$db" < "$f" | wc -l)
    if [ "$rows" -eq 0 ]; then
        printf 'PASS  %s\n' "$f"
    else
        printf 'FAIL  %s  (%d violating rows)\n' "$f" "$rows"
        sqlite3 -box "$db" < "$f" | head -15
        fail=1
    fi
done

exit "$fail"
```

Run it from the course root:

```bash
bash tests/run_tests.sh
```

```text
PASS  tests/test_addresses_one_default.sql
PASS  tests/test_customers_email_unique.sql
PASS  tests/test_order_items_grain.sql
PASS  tests/test_orders_freshness.sql
PASS  tests/test_orders_status_values.sql
PASS  tests/test_orders_valid_customer.sql
```

The nonzero exit code on failure is the point: this script drops straight into cron, CI, or an orchestrator task, and a broken invariant stops the pipeline *before* the broken numbers reach a dashboard. Run it after every data load and before shipping any query that assumes one of these invariants.

> **PostgreSQL note:** the pattern is identical (`psql -f test.sql`, or `psql --csv` piped to `wc -l` minus the header). More importantly, this is *exactly* what dbt tests are: `unique`, `not_null`, `relationships`, and `accepted_values` in a dbt `schema.yml` generate precisely these assertion queries and run them for you. You now know what's under that hood.

## 6. A code-review checklist for SQL

Reviewing SQL is not proofreading — it's hunting for the five or six failure modes that recur forever. Walk the list every time; after a few months it becomes how you *read* SQL:

1. **Grain stated and true?** Does a comment say what one row is — and would a `GROUP BY`-plus-`HAVING` uniqueness probe on that key return zero rows?
2. **Fan-out checked?** For every join: is the right side unique on the join key? If not, is the multiplication intended? (One-to-many joined *before* aggregation is Pitfall 2 below.)
3. **Population explicit?** Is `status <> 'cancelled'` (or whatever defines the population) written down, or is the query relying on a join to drop rows accidentally?
4. **NULLs handled?** `NOT IN` against a nullable column (Module 4)? Aggregates over columns with meaningful NULLs (Module 3)? Comparisons that silently become UNKNOWN (Module 2)?
5. **Dates half-open?** `>= start AND < end`; no `BETWEEN` on timestamps; no fencepost losses on the last day.
6. **Metrics canonical?** Does "revenue" here match the organization's (here: DATASET.md's) definition — discounts applied, cancelled excluded, refunds handled per gross vs net?
7. **No `SELECT *`** in anything saved; every computed column named.
8. **Predicates index-friendly?** Filters on bare columns, not on `strftime(...)`-wrapped ones (Module 10) — or an expression index exists to match.
9. **Deterministic output?** Ties broken in `ORDER BY` when `LIMIT` is involved (Module 1); `ROW_NUMBER` has a full tiebreaker (Module 6).
10. **Tested?** Does at least one assertion query guard the invariant this query depends on, and does a total reconcile against an independently computed number?

## 7. Performance-aware habits (Module 10, distilled)

Style and performance advice mostly point the same direction. Habits to keep without thinking:

- Filter early (in import CTEs), aggregate before joining when the join would multiply rows, and select only needed columns.
- Keep predicates **sargable**: `ordered_at >= '2025-01-01'` beats `strftime('%Y', ordered_at) = '2025'` — the former can use an index on `ordered_at`, the latter never can.
- Check any query you'll run repeatedly with `EXPLAIN QUERY PLAN`; look for full `SCAN`s of big tables where a `SEARCH ... USING INDEX` was possible.
- Remember what indexes cost (Module 10): every write maintains them — index for the queries you actually run, not the ones you imagine.
- Don't micro-optimize a query nobody runs twice. Do optimize (and test!) anything scheduled.

## 8. When NOT to use SQL

SQL is declarative set logic; it's the wrong tool when the problem isn't one:

- **Procedural, order-dependent logic** — retry loops, branching workflows, "call this API for each row." Recursive CTEs *can* fake iteration, but at some complexity the honest answer is twenty lines of Python around a thin query.
- **Heavy string parsing** — extracting structure from log lines or free text. `substr`/`LIKE` acrobatics become write-only fast; regex-capable languages exist. Parse outside, store *structured*, query in SQL.
- **Statistical modeling and ML** — a mean or percentile is SQL; regressions, clustering, and anything with a training loop belongs in a stats/ML library. SQL's job is building the clean feature table.
- **Per-entity simulation, complex graph algorithms** (shortest path with weights, PageRank), and matrix math — expressible, occasionally, but unreadable and slow.

The professional pattern is not "SQL vs Python"; it's SQL for the set-based 90% — filtering, joining, aggregating at data-scale — handing compact results to procedural code for the rest.

## 9. The ecosystem map

Where what you've learned runs, and what the names in job postings mean:

**SQLite** — an embedded library, not a server: the whole database is one file, and it runs inside your process. It's in every phone, browser, and OS image on earth. Ideal for local analysis, embedded apps, tests, and courses like this one; wrong for many concurrent writers (single-writer design) or client-server deployments.

**PostgreSQL** — the default choice for a serious operational (OLTP) database and this course's constant comparison point: strict typing, real dates and booleans, rich SQL (every window/CTE feature you learned, plus `jsonb`, arrays, extensions like PostGIS), MVCC concurrency, and open-source with no strings. If you learn one server database deeply, pick this.

**MySQL / MariaDB** — the other big open-source OLTP family, powering an enormous share of the web (WordPress, older SaaS stacks). Historically looser SQL and weaker analytics than PostgreSQL (window functions and CTEs only landed in MySQL 8), but ubiquitous — you *will* meet it.

**DuckDB** — SQLite's analytical twin: embedded, single-file, zero-config, but columnar and vectorized, built for OLAP. It queries Parquet/CSV files in place and chews through millions of rows on a laptop. Rapidly becoming the standard local tool for the kind of analytics in Modules 6 and 11.

**Cloud warehouses — Snowflake, BigQuery, Redshift** — managed, columnar, massively parallel databases for organization-wide analytics: terabytes are routine, storage and compute scale (and bill) separately. The SQL is the same language you now know, with dialect trims (BigQuery's `QUALIFY`, Snowflake's zero-copy cloning). Your window-function and CTE skills transfer almost verbatim.

**dbt** — not a database: a framework that turns the Section 4 pattern into a project. Each model is a SELECT in a file; dbt wires the dependency graph (`ref()`), materializes models as views/tables in your warehouse, runs generated assertion tests (Section 5), and renders documentation. It's SQL style and structure, industrialized.

**Orchestrators — Airflow, Dagster, Prefect** — schedulers for data work: run the load at 02:00, then the tests, then dbt, then refresh dashboards; retry on failure, alert on red. Your `run_tests.sh` exiting nonzero is exactly the contract an orchestrator task expects.

## Pitfalls

### Pitfall 1: write-only SQL

Ops asks: *which carrier is slowest, and how often does each blow the 7-day SLA?* This lands in the repo:

```sql
-- BAD: works, but nobody can review it — one line, cryptic aliases,
-- ordinals, and the transit-time formula repeated three times
select carrier,count(*) n,round(avg(julianday(delivered_at)-julianday(shipped_at)),1) avgd,round(100.0*sum(case when julianday(delivered_at)-julianday(shipped_at)>7 then 1 else 0 end)/count(*),1) late from shipments where delivered_at is not null group by 1 order by 4 desc;
```

```text
╭──────────┬──────┬──────┬──────╮
│ carrier  │  n   │ avgd │ late │
╞══════════╪══════╪══════╪══════╡
│ DPD      │ 1053 │  5.6 │ 33.2 │
│ PostNord │ 1090 │  5.5 │ 33.1 │
│ UPS      │ 1096 │  5.5 │ 32.8 │
│ DHL      │ 1065 │  5.4 │ 31.9 │
│ Bring    │ 1075 │  5.4 │ 31.1 │
╰──────────┴──────┴──────┴──────╯
```

The output is right and still fails review: what is `late` — a count? a percentage? of what denominator? Do in-transit shipments count against the carrier? You must execute the whole line in your head to know. The fix costs nothing at runtime — name the formula once in a CTE, name every output column, keep one clause per line:

```sql
WITH transit AS (
    SELECT
        carrier,
        julianday(delivered_at) - julianday(shipped_at) AS transit_days
    FROM shipments
    WHERE delivered_at IS NOT NULL      -- in-transit shipments can't be judged
)
SELECT
    carrier,
    COUNT(*)                                          AS delivered_shipments,
    ROUND(AVG(transit_days), 1)                       AS avg_transit_days,
    ROUND(100.0 * SUM(CASE WHEN transit_days > 7 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                              AS pct_late
FROM transit
GROUP BY carrier
ORDER BY pct_late DESC;
```

```text
╭──────────┬─────────────────────┬──────────────────┬──────────╮
│ carrier  │ delivered_shipments │ avg_transit_days │ pct_late │
╞══════════╪═════════════════════╪══════════════════╪══════════╡
│ DPD      │                1053 │              5.6 │     33.2 │
│ PostNord │                1090 │              5.5 │     33.1 │
│ UPS      │                1096 │              5.5 │     32.8 │
│ DHL      │                1065 │              5.4 │     31.9 │
│ Bring    │                1075 │              5.4 │     31.1 │
╰──────────┴─────────────────────┴──────────────────┴──────────╯
```

Now the column names answer the reviewer's questions, and the `WHERE ... IS NOT NULL` comment records the one real business decision. Same rows, reviewable in thirty seconds.

### Pitfall 2: the untested "obviously correct" report

Finance asks for **2025 gross revenue by payment method**. Join orders to items for revenue, to payments for the method, keep only real (captured) payments — obviously correct:

```sql
-- BAD: reads correctly, reviews correctly, and is wrong — payments is
-- one-to-many with orders, and the join multiplies item revenue
SELECT
    p.method,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN payments    AS p  ON p.order_id  = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01'
  AND o.ordered_at <  '2026-01-01'
  AND p.status = 'captured'
GROUP BY p.method
ORDER BY gross_revenue DESC;
```

```text
╭───────────────┬───────────────╮
│    method     │ gross_revenue │
╞═══════════════╪═══════════════╡
│ card          │     520250.94 │
│ paypal        │      248991.3 │
│ klarna        │      237282.7 │
│ bank_transfer │     122819.84 │
│ refund        │      31140.61 │
╰───────────────┴───────────────╯
```

That `refund` line is a smell (a refund isn't how anyone *paid*), but the deeper damage is invisible: some orders' items are being counted **twice**. Eyeballing won't prove it. A **reconciliation assertion** will — the sliced total must equal the same total computed independently, without the risky join:

```sql
WITH by_method AS (
    SELECT
        p.method,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    JOIN payments    AS p  ON p.order_id  = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
      AND p.status = 'captured'
    GROUP BY p.method
),
expected AS (
    SELECT SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS total
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
      AND EXISTS (SELECT 1 FROM payments AS p
                  WHERE p.order_id = o.order_id AND p.status = 'captured')
)
SELECT
    ROUND((SELECT SUM(gross_revenue) FROM by_method), 2) AS breakdown_total,
    ROUND(e.total, 2)                                    AS expected_total,
    ROUND((SELECT SUM(gross_revenue) FROM by_method) - e.total, 2) AS diff
FROM expected AS e
WHERE ABS((SELECT SUM(gross_revenue) FROM by_method) - e.total) > 0.01;
```

```text
╭─────────────────┬────────────────┬──────────╮
│ breakdown_total │ expected_total │   diff   │
╞═════════════════╪════════════════╪══════════╡
│       1160485.4 │     1129344.78 │ 31140.61 │
╰─────────────────┴────────────────┴──────────╯
```

A row came back: **test failed**, we're over by 31,140.61 — exactly the `refund` line. The `EXISTS` in `expected` counts each order once no matter how many payment rows it has; the join in `by_method` doesn't. Probe the grain assumption the join silently made:

```sql
SELECT COUNT(*) AS orders_with_multiple_captured
FROM (
    SELECT order_id
    FROM payments
    WHERE status = 'captured'
    GROUP BY order_id
    HAVING COUNT(*) > 1
);
```

```text
╭───────────────────────────────╮
│ orders_with_multiple_captured │
╞═══════════════════════════════╡
│                           172 │
╰───────────────────────────────╯
```

There it is — the 172 *returned* orders each have two captured rows: the original capture **and** the refund (refunds are captured negative-amount rows, DATASET.md). Each such order's items were summed once under `card`/`klarna`/... and once more under `refund`. Fix it the Section 4 way: build an import CTE that is *guaranteed* one-row-per-order, and join at order grain:

```sql
WITH order_payment_method AS (      -- import: exactly one row per paid order
    SELECT order_id, method
    FROM payments
    WHERE status = 'captured'
      AND method <> 'refund'
)
SELECT
    pm.method,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN order_payment_method AS pm ON pm.order_id = o.order_id
JOIN order_items          AS oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01'
  AND o.ordered_at <  '2026-01-01'
GROUP BY pm.method
ORDER BY gross_revenue DESC;
```

```text
╭───────────────┬───────────────╮
│    method     │ gross_revenue │
╞═══════════════╪═══════════════╡
│ card          │     520250.94 │
│ paypal        │      248991.3 │
│ klarna        │      237282.7 │
│ bank_transfer │     122819.84 │
╰───────────────┴───────────────╯
```

Rerun the reconciliation with `by_method` swapped for the fixed version:

```sql
WITH by_method AS (
    SELECT
        pm.method,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS gross_revenue
    FROM orders AS o
    JOIN (SELECT order_id, method
          FROM payments
          WHERE status = 'captured' AND method <> 'refund') AS pm
         ON pm.order_id = o.order_id
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
    GROUP BY pm.method
),
expected AS (
    SELECT SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS total
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2025-01-01'
      AND o.ordered_at <  '2026-01-01'
      AND EXISTS (SELECT 1 FROM payments AS p
                  WHERE p.order_id = o.order_id AND p.status = 'captured')
)
SELECT
    ROUND((SELECT SUM(gross_revenue) FROM by_method), 2) AS breakdown_total,
    ROUND(e.total, 2)                                    AS expected_total
FROM expected AS e
WHERE ABS((SELECT SUM(gross_revenue) FROM by_method) - e.total) > 0.01;
```

```text
(zero rows returned — the breakdown reconciles, the test passes)
```

Two lessons. First, checklist item 2 (*is the right side of every join unique on the join key?*) would have caught this before it ran. Second — and this is the module's thesis — "the query looks right" is not evidence. The reconciliation test produced evidence in one execution, and if it lives in `tests/`, it keeps producing evidence every time the data or the query changes. One scope note belongs in the report's header, too: this breakdown covers orders *with a captured payment* — canonical gross revenue also includes not-yet-paid pending orders, which is why `expected` is scoped with the same `EXISTS`.

## Exercises

Your refactors must return **exactly** the same rows as the queries given. For test-writing exercises, follow the suite conventions: violating-rows form, zero rows = pass, one file per test in `tests/`. No answers here — solutions (with reference refactors) are in `solutions/12-sql-style-and-structure.md`.

**Warm-up**

1. Marketing wants the five countries with the highest newsletter opt-in rate. The query below is correct; reformat it to the style guide (explicit names, one clause per line, no repeated formula left unnamed, no ordinals). Same five rows required.

```sql
select country,sum(case when marketing_opt_in=1 then 1 else 0 end) optin,count(*) total,round(100.0*sum(case when marketing_opt_in=1 then 1 else 0 end)/count(*),1) pct from customers group by country order by pct desc limit 5;
```

```text
╭────────────────┬───────┬───────┬──────╮
│    country     │ optin │ total │ pct  │
╞════════════════╪═══════╪═══════╪══════╡
│ Switzerland    │    14 │    31 │ 45.2 │
│ Norway         │    43 │    98 │ 43.9 │
│ United Kingdom │    30 │    69 │ 43.5 │
│ Denmark        │    43 │   101 │ 42.6 │
│ Germany        │    47 │   115 │ 40.9 │
╰────────────────┴───────┴───────┴──────╯
```

2. A colleague proposes this table for Nordkart's new returns feature (shown as a sketch — don't run it). List every naming violation and rewrite the DDL with compliant names.

```text
CREATE TABLE Return (
    id        INTEGER PRIMARY KEY,
    order     INTEGER REFERENCES orders(order_id),
    desc      TEXT,
    approved  INTEGER,          -- 0/1
    Date      TEXT
);
```

3. The query below is correct but undocumented. Write its header block: one-line purpose, its exact **grain** (careful — it's not "one row per customer"), and a note reconciling its `spend` column against the canonical definitions in DATASET.md (what does it include and exclude?).

```sql
SELECT
    o.customer_id,
    strftime('%Y-%m', o.ordered_at) AS order_month,
    ROUND(SUM(oi.quantity * oi.unit_price
              * (1 - oi.discount_pct / 100.0)), 2) AS spend
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY o.customer_id, order_month
ORDER BY o.customer_id, order_month
LIMIT 6;
```

```text
╭─────────────┬─────────────┬─────────╮
│ customer_id │ order_month │  spend  │
╞═════════════╪═════════════╪═════════╡
│           2 │ 2024-03     │  315.12 │
│           2 │ 2026-06     │   847.8 │
│           3 │ 2025-09     │  541.41 │
│           3 │ 2026-06     │ 1089.93 │
│           4 │ 2025-10     │  487.57 │
│           4 │ 2025-11     │ 2523.66 │
╰─────────────┴─────────────┴─────────╯
```

**Core**

4. Growth wants new vs returning customers per month for 2025 ("new" = that month is the customer's first-ever non-cancelled order month). This monolith is correct; refactor it into a layered CTE pipeline — import CTE, one-idea logical CTEs, presentation-only final SELECT, a header stating the grain — producing identical output. Bonus: say why the refactor should also *run* faster (think about what the correlated subquery does per row).

```sql
select m,sum(case when m=fm then 1 else 0 end) new_customers,sum(case when m>fm then 1 else 0 end) returning_customers from (select distinct o.customer_id,strftime('%Y-%m',o.ordered_at) m,(select min(strftime('%Y-%m',o2.ordered_at)) from orders o2 where o2.customer_id=o.customer_id and o2.status<>'cancelled') fm from orders o where o.status<>'cancelled') where m like '2025%' group by m order by m;
```

```text
╭─────────┬───────────────┬─────────────────────╮
│    m    │ new_customers │ returning_customers │
╞═════════╪═══════════════╪═════════════════════╡
│ 2025-01 │             5 │                  66 │
│ 2025-02 │            11 │                  62 │
│ 2025-03 │            11 │                  83 │
│ 2025-04 │            18 │                  78 │
│ 2025-05 │            19 │                  77 │
│ 2025-06 │            13 │                 109 │
│ 2025-07 │            15 │                 116 │
│ 2025-08 │            11 │                 105 │
│ 2025-09 │            15 │                 121 │
│ 2025-10 │            21 │                 107 │
│ 2025-11 │            25 │                 174 │
│ 2025-12 │            26 │                 218 │
╰─────────┴───────────────┴─────────────────────╯
```

5. Fulfillment invariant: **every delivered order has at least one shipment.** Write it as `tests/test_delivered_have_shipment.sql` (violating-rows form), add it to the suite, and confirm the suite still runs green.

6. Finance invariant: **for every delivered order, captured payments sum to the order total** (canonical order total: item revenue + shipping_cost). Write it as `tests/test_payments_reconcile.sql`. Money is `REAL`, so exact equality will produce false alarms — allow a tolerance of 0.01, and make the test also flag delivered orders with *no* captured payment at all.

7. Catalog invariant (the SCD shape from DATASET.md): **every active product has exactly one current `price_history` row (`valid_to IS NULL`), and that row's price equals `products.unit_price`.** Write it as one test file, `tests/test_price_history_current.sql`, covering both halves (hint: `UNION ALL` two violation queries, with a `problem` label column).

8. Ops wants to know the same day the clickstream pipeline stalls. Write `tests/test_events_freshness.sql` asserting the newest `events.occurred_at` is on/after `2026-07-01` (pinned for this frozen dataset), and add a comment giving the rolling-window version you'd use in production and *why* pinned thresholds are wrong there.

**Challenge**

9. This landed in your review queue: "2025 AOV by country." It runs, and every number in it is wrong. Find the **four distinct correctness defects** (style gripes don't count toward the four; two defects are about *which orders* end up in the population, one is about *row multiplication*, one is about *the metric itself*). Write the review comment you'd leave for each, then the corrected query per the canonical AOV definition — and predict before running: will correct AOVs be higher or lower?

```sql
SELECT c.country, ROUND(AVG(oi.quantity * oi.unit_price), 2) AS aov, COUNT(*) AS orders
FROM customers c, orders o, order_items oi, payments p
WHERE o.customer_id = c.customer_id
  AND oi.order_id = o.order_id
  AND p.order_id = o.order_id
  AND strftime('%Y', o.ordered_at) = '2025'
GROUP BY c.country
ORDER BY 2 DESC;
```

```text
╭────────────────┬────────┬────────╮
│    country     │  aov   │ orders │
╞════════════════╪════════╪════════╡
│ Netherlands    │ 262.38 │    446 │
│ Germany        │ 261.04 │    662 │
│ Finland        │  254.9 │    307 │
│ Denmark        │ 249.84 │    595 │
│ United Kingdom │ 246.44 │    391 │
│ Switzerland    │ 244.49 │    238 │
│ Sweden         │ 241.38 │   1561 │
│ Norway         │ 240.01 │    516 │
│ France         │  216.8 │    241 │
│ Austria        │ 214.45 │    118 │
╰────────────────┴────────┴────────╯
```

10. A test you've never seen fail is a test you can't trust. Prove the suite works: copy the database (`cp shop.db /tmp/broken.db` — **never** touch `shop.db`), corrupt one invariant with a single `UPDATE` (e.g. give some customer a second default address), run the suite against the copy, and confirm (a) exactly the right test fails, (b) the violating rows printed identify the row you broke, and (c) the runner's exit code is nonzero (`echo $?`). Explain in one sentence why this "test the test" drill belongs in real projects.

## Key takeaways

- **Style:** UPPERCASE keywords / lowercase `snake_case` identifiers; one clause per line; one select-item per line; trailing commas; every table aliased with `AS`; every computed column named; no `SELECT *`, no ordinals in saved SQL; half-open date ranges.
- **Names:** plural tables (pick a lane, keep it); `table_id` keys on both sides of every join; `is_`/`has_` booleans; `_at` timestamps; `v_` views, `stg_` staging; never reserved words.
- **Grain:** every non-trivial query documents what one row is; most double-count bugs are undocumented grain violations. Header = purpose + grain + definitions; inline comments = WHY only.
- **Pipeline:** import CTEs (select/filter/rename only) → logical CTEs (one idea each, named for what they are) → final SELECT (presentation only). Debug by running CTEs individually. dbt = this pattern, industrialized.
- **Testing:** assertion query = SELECT the violations; zero rows = pass. Families: uniqueness, grain, referential integrity, accepted values, business rules, freshness, reconciliation of sliced totals against independent totals. `bash tests/run_tests.sh` — nonzero exit stops pipelines.
- **Review checklist:** grain? fan-out? population explicit? NULLs? half-open dates? canonical metrics? no `SELECT *`? sargable predicates? deterministic ties? tested?
- **Fan-out rule of thumb:** before joining, know whether the right side is unique on the join key; if it isn't, aggregate it to that grain first.
- **Reach for another language** when logic is procedural, statistical, or string-parsing heavy; keep SQL for set logic.
- **Ecosystem:** SQLite/DuckDB embedded (OLTP-ish/OLAP), PostgreSQL/MySQL servers, Snowflake/BigQuery/Redshift warehouses, dbt for transformation structure, orchestrators to schedule it all.

## Appendix: PostgreSQL migration cheatsheet

Everything this course flagged in "PostgreSQL note" callouts, in one table. SQLite → PostgreSQL:

| Topic | SQLite (this course) | PostgreSQL |
|---|---|---|
| Connecting | file: `sqlite3 shop.db` | server: `psql mydb`; `\dt` ≈ `.tables`, `\d orders` ≈ `.schema orders`, `\q` quits |
| Types | affinity, anything-goes unless `STRICT` | rigid types: `integer`, `numeric`, `text`, `boolean`, `date`, `timestamp`, `timestamptz`, `uuid`, `jsonb` |
| Booleans | `INTEGER` 0/1 + `CHECK` | real `boolean` (`TRUE`/`FALSE`), `WHERE is_active` works bare |
| Auto-increment keys | `INTEGER PRIMARY KEY` rowid | `GENERATED ALWAYS AS IDENTITY` (modern) or legacy `serial` |
| Money | `REAL` (course simplification) | `numeric(12,2)` — exact, no float tolerance games |
| Identifier case | as typed | unquoted folds to lowercase; quoted names quoted forever — use `snake_case` |
| `LIKE` | case-insensitive for ASCII | case-sensitive; use `ILIKE` for insensitive |
| Casts | `CAST(x AS INTEGER)` | same, plus shorthand `x::integer` |
| Integer division | truncates | truncates too — portable trap; multiply by `1.0` or cast |
| `ROUND(x, 2)` | works on any numeric | on `double precision` requires `round(x::numeric, 2)`; display via `to_char` |
| Dates/times | TEXT + `date()`, `strftime()`, `julianday()` | real types + `date_trunc('month', ts)`, `to_char(ts, 'YYYY-MM')`, `ts + interval '7 days'`, subtraction of timestamps yields an `interval` |
| Date series | recursive CTE spine | `generate_series(start, end, '1 day')` |
| NULL sort order | NULLs first (ASC) | NULLs *last* (ASC) — opposite; write `NULLS FIRST`/`NULLS LAST` explicitly |
| `GROUP BY` strictness | silently picks arbitrary row for ungrouped columns | error unless grouped, aggregated, or functionally dependent on a grouped PK — treat the error as a friend |
| Bare aliases in `ORDER BY` | allowed anywhere, even in expressions | plain alias OK; alias *inside an expression* not — repeat the expression or use a CTE |
| Conditional aggregates | `CASE WHEN` (or `FILTER` 3.30+) | `COUNT(*) FILTER (WHERE ...)` — standard, prefer it |
| Scalar subquery returning >1 row | silently takes first row | runtime error — safer |
| `RIGHT`/`FULL JOIN` | 3.39+ | always supported |
| `NOT IN` + NULL trap | identical | identical — standard three-valued logic; use `NOT EXISTS` |
| `INTERSECT ALL`/`EXCEPT ALL` | missing (`ALL` only on `UNION`) | supported |
| Window functions | full support | identical (SQL standard), plus named `WINDOW` clause in both |
| Percentiles | manual (ordered `LIMIT`/window tricks, Module 11) | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY x)` |
| CTE materialization | inlined when profitable | v12+ same; force with `AS [NOT] MATERIALIZED`; ≤v11 always materialized (source of "CTEs are slow" folklore) |
| Recursive CTEs | `WITH RECURSIVE` | same, plus `SEARCH`/`CYCLE` clauses (v14+) |
| UPSERT | `INSERT ... ON CONFLICT DO UPDATE` | same syntax (SQLite copied PostgreSQL's) |
| `RETURNING` | supported | supported (it originated here) |
| FK enforcement | off unless `PRAGMA foreign_keys = ON` per connection | always on |
| Query plans | `EXPLAIN QUERY PLAN` | `EXPLAIN` (estimates) / `EXPLAIN ANALYZE` (executes + real timings) |
| Planner statistics | `ANALYZE` (manual) | `ANALYZE` + autovacuum keeps them fresh automatically |
| Index types | B-tree, partial, expression, covering via included columns in index | same concepts, plus GIN (jsonb/full-text), GiST/BRIN, `CREATE INDEX CONCURRENTLY`, `INCLUDE (...)` for covering |
| Views | plain views only | plain + **materialized** views (`REFRESH MATERIALIZED VIEW`) |
| Transactions & isolation | file-level locking; one writer at a time | MVCC — readers never block writers; isolation levels `READ COMMITTED` (default), `REPEATABLE READ`, `SERIALIZABLE` |
| JSON | `json_extract()` / `->>` (3.38+), JSON stored as TEXT | `jsonb` binary type: indexable (GIN), `@>` containment, rich operator set |
| Semi-structured / arrays | not really | native arrays, `unnest()`, composite types |
| System catalog | `sqlite_master`, `PRAGMA table_info(t)` | `information_schema.*`, `pg_catalog` (`pg_tables`, `pg_indexes`) |
| Schemas/namespaces | one namespace per file (`ATTACH` for more) | schemas within a database (`analytics.orders`), `search_path` |

The deeper migration lesson from eleven modules of callouts: everything *conceptual* transfers — joins, NULL logic, grain, windows, CTE pipelines, testing discipline. What changes is strictness (PostgreSQL refuses what SQLite guesses at) and machinery (real types, real concurrency, more index tricks). Moving from SQLite to PostgreSQL mostly feels like turning on a stricter compiler for skills you already have.
