# Module 5 — Subqueries & CTEs

Real analytical questions rarely fit in one SELECT. "Which products are overpriced *relative to their category*?" needs an average computed per category *inside* a query about products. "How did revenue move month over month?" needs monthly totals *before* you can compare them. Subqueries and common table expressions (CTEs) are SQL's tools for composing queries out of smaller queries — and for a data engineer, the CTE pipeline is the single most important structuring device you will use: almost every production analytics query is a chain of named steps.

This module runs read-only against `shop.db` — no copy needed.

## What you'll learn

- Scalar subqueries in SELECT and WHERE, and the difference between correlated and uncorrelated subqueries (including why correlation can be catastrophically slow)
- Subqueries with `IN`, including nesting them
- Derived tables — a subquery in FROM — and why aggregating an aggregate requires one
- `WITH ... AS` CTEs: naming intermediate steps, chaining multiple CTEs, referencing one CTE from another (and from two places at once)
- Building a real multi-step pipeline: order revenue → monthly revenue → month-over-month comparison
- When to reach for a CTE vs a derived table vs a view
- Set operations: `UNION ALL`, `UNION`, `INTERSECT`, `EXCEPT`
- Recursive CTEs: walking the category tree (full paths, depth, roll-ups) and generating a calendar spine to find days with zero orders

## 1. Scalar subqueries

A **scalar subquery** is a parenthesized SELECT that returns exactly one row with one column — so it can stand anywhere a single value can: in the SELECT list, in a WHERE comparison, even inside an expression.

The classic use: compare each row to a global statistic. How does each product's price relate to the catalog-wide average?

```sql
SELECT
    name,
    unit_price,
    (SELECT ROUND(AVG(unit_price), 2) FROM products) AS catalog_avg,
    ROUND(unit_price - (SELECT AVG(unit_price) FROM products), 2) AS diff
FROM products
ORDER BY diff DESC
LIMIT 5;
```

```text
╭─────────────────────────┬────────────┬─────────────┬────────╮
│          name           │ unit_price │ catalog_avg │  diff  │
╞═════════════════════════╪════════════╪═════════════╪════════╡
│ Drift Inflatable Kayak  │    1004.85 │       206.4 │ 798.45 │
│ Fjord Sit-on-Top Kayak  │     934.86 │       206.4 │ 728.46 │
│ Probe Airbag Pack       │     893.33 │       206.4 │ 686.93 │
│ Rescue Avalanche Beacon │     834.53 │       206.4 │ 628.13 │
│ Tele Touring Skis       │     775.98 │       206.4 │ 569.58 │
╰─────────────────────────┴────────────┴─────────────┴────────╯
```

Without a subquery this is impossible in one pass: `AVG(unit_price)` is an aggregate (one value for the whole table), while `unit_price` is a per-row value. Module 3 told you that you can't mix the two in one SELECT — the scalar subquery is the escape hatch: it computes the aggregate in its own little query and hands the result over as a constant.

The same trick works in WHERE. How many products are priced above the catalog average?

```sql
SELECT COUNT(*) AS above_avg_products
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products);
```

```text
╭────────────────────╮
│ above_avg_products │
╞════════════════════╡
│                128 │
╰────────────────────╯
```

128 of 350 — the price distribution is right-skewed (a few expensive kayaks and skis pull the mean up). Note that you could **not** write `WHERE unit_price > AVG(unit_price)`: WHERE runs before aggregation, so bare aggregates are illegal there. The subquery sidesteps that by being a complete, independently evaluated query.

## 2. Correlated subqueries: comparing each row to its own group

The subqueries above are **uncorrelated**: they mention nothing from the outer query, so the engine can evaluate them once and reuse the value. A **correlated** subquery references a column of the outer query — its result depends on the current outer row, so *conceptually* it must be re-evaluated for every row.

The catalog-wide average is a blunt instrument — of course a kayak costs more than a beanie. The fair comparison is each product against **its own category's** average:

```sql
SELECT
    p.name,
    c.name AS category,
    p.unit_price,
    (SELECT ROUND(AVG(p2.unit_price), 2)
     FROM products p2
     WHERE p2.category_id = p.category_id) AS category_avg
FROM products p
JOIN categories c ON c.category_id = p.category_id
ORDER BY p.unit_price - category_avg DESC
LIMIT 5;
```

```text
╭─────────────────────────┬──────────────────┬────────────┬──────────────╮
│          name           │     category     │ unit_price │ category_avg │
╞═════════════════════════╪══════════════════╪════════════╪══════════════╡
│ Drift Inflatable Kayak  │ Kayaks           │    1004.85 │        487.3 │
│ Fjord Sit-on-Top Kayak  │ Kayaks           │     934.86 │        487.3 │
│ Probe Airbag Pack       │ Avalanche Safety │     893.33 │       450.53 │
│ Rescue Avalanche Beacon │ Avalanche Safety │     834.53 │       450.53 │
│ Tele Touring Skis       │ Skis             │     775.98 │       443.02 │
╰─────────────────────────┴──────────────────┴────────────┴──────────────╯
```

The correlation is `WHERE p2.category_id = p.category_id`: the inner query reads `p.category_id` from the *outer* row. Each product now gets the average of its own category. Two details worth noticing:

- We aliased the inner table `p2`. Without distinct aliases, `category_id = category_id` would be ambiguous (or worse, silently self-referential inside the subquery).
- SQLite lets `ORDER BY` reuse the output alias `category_avg` inside an expression, so we don't have to repeat the subquery.

> **PostgreSQL note:** PostgreSQL accepts a bare output alias in `ORDER BY` (`ORDER BY category_avg`) but **not** an alias inside a larger expression like `p.unit_price - category_avg`. For portable SQL, repeat the expression or compute it in a prior step (you'll see how with CTEs below).

Correlated subqueries work in WHERE too. How many products are priced above their own category's average?

```sql
SELECT COUNT(*) AS above_category_avg
FROM products p
WHERE p.unit_price > (SELECT AVG(p2.unit_price)
                      FROM products p2
                      WHERE p2.category_id = p.category_id);
```

```text
╭────────────────────╮
│ above_category_avg │
╞════════════════════╡
│                167 │
╰────────────────────╯
```

167 — close to half, as you'd expect when comparing values to their own group mean (contrast with the 128 against the skewed global mean).

**The performance implication.** An uncorrelated subquery costs one extra query. A correlated subquery is, naively, one extra query *per outer row* — O(rows × subquery cost). Optimizers often rescue you (SQLite builds transient automatic indexes; other engines rewrite the correlation into a join), but they can't always, and the failure mode is brutal: a query that works on 1,000 rows and takes an hour on 1,000,000. The Pitfalls section demonstrates a real 2,500× slowdown and the mechanical rewrite that fixes it. Rule of thumb: correlated subqueries are fine for *lookups along an indexed key*; for anything aggregating per group, compute the groups once (GROUP BY in a CTE) and join.

## 3. Subqueries with IN

When the inner query legitimately returns *many* rows, compare with `IN` instead of `=`. You met `IN (list)` in Module 2 and semi-joins in Module 4 — `IN (subquery)` is the bridge between them: the list is computed by a query.

Which are the five most expensive Climbing products? Products link to *child* categories, so we need the set of category ids under "Climbing":

```sql
SELECT name, unit_price
FROM products
WHERE category_id IN (
    SELECT category_id
    FROM categories
    WHERE parent_category_id =
          (SELECT category_id FROM categories WHERE name = 'Climbing')
)
ORDER BY unit_price DESC
LIMIT 5;
```

```text
╭──────────────────────┬────────────╮
│         name         │ unit_price │
╞══════════════════════╪════════════╡
│ Dyna Sling 120cm     │     275.91 │
│ Flux Rope 60m        │     266.93 │
│ Dyna Rope 70m        │      263.8 │
│ Anchor Sling 120cm   │     254.91 │
│ Dyna Static Rope 40m │     245.65 │
╰──────────────────────┴────────────╯
```

Read it inside-out: the innermost scalar subquery resolves the name 'Climbing' to its id; the middle query returns the ids of Climbing's child categories; the outer query keeps products in that set. No magic numbers hard-coded anywhere.

Subqueries nest to any depth. A merchandising question: how many orders contain at least one now-discontinued product (stock we can't reorder)?

```sql
SELECT COUNT(*) AS orders_with_discontinued
FROM orders
WHERE order_id IN (
    SELECT order_id
    FROM order_items
    WHERE product_id IN (SELECT product_id FROM products WHERE is_active = 0)
);
```

```text
╭──────────────────────────╮
│ orders_with_discontinued │
╞══════════════════════════╡
│                      737 │
╰──────────────────────────╯
```

This is a semi-join written with `IN`; `EXISTS` from Module 4 would express it equally well. And the Module 4 warning stands: **never** use `NOT IN (subquery)` when the subquery can return NULL — one NULL makes the whole predicate return no rows. Prefer `NOT EXISTS`.

## 4. Derived tables: a subquery in FROM

Everything so far produced a *value* or a *set of values*. A subquery in the FROM clause produces a whole **table** — called a derived table — that the outer query treats like any other table. This is how you aggregate an aggregate.

"What's the average number of items in an order?" needs two levels: first sum quantities per order, *then* average those sums. One GROUP BY can't do both:

```sql
SELECT ROUND(AVG(items_in_order), 2) AS avg_items_per_order
FROM (
    SELECT order_id, SUM(quantity) AS items_in_order
    FROM order_items
    GROUP BY order_id
) AS per_order;
```

```text
╭─────────────────────╮
│ avg_items_per_order │
╞═════════════════════╡
│                2.72 │
╰─────────────────────╯
```

The inner query collapses 13,475 order lines into 6,000 per-order rows; the outer query averages them. The alias `AS per_order` is required — a derived table must have a name.

The same shape computes Nordkart's **AOV** (average order value — the canonical definition: average *order total* across *non-cancelled* orders, where order total = item revenue + shipping):

```sql
SELECT ROUND(AVG(order_total), 2) AS aov
FROM (
    SELECT
        o.order_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
) AS order_totals;
```

```text
╭────────╮
│  aov   │
╞════════╡
│ 548.65 │
╰────────╯
```

Note `GROUP BY o.order_id` while selecting `o.shipping_cost` outside any aggregate: that's legal here because `order_id` is the primary key, so `shipping_cost` is constant within each group.

> **PostgreSQL note:** PostgreSQL enforces the "every selected column must be grouped or aggregated" rule strictly, but it recognizes functional dependence on a primary key — grouping by `o.order_id` makes `o.shipping_cost` legal there too. Grouping by a non-key column and selecting ungrouped columns is an error in PostgreSQL, while SQLite silently picks an arbitrary row: don't rely on that.

Derived tables work, but they read inside-out, and nesting two or three of them turns a query into a bracket-matching puzzle. Enter the workhorse.

## 5. CTEs — `WITH ... AS`, the workhorse

A **common table expression** is a derived table hoisted to the top of the query and given a name *before* the main SELECT. Same semantics, radically better readability. The AOV query again:

```sql
WITH order_totals AS (
    SELECT
        o.order_id,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
            + o.shipping_cost AS order_total
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
)
SELECT ROUND(AVG(order_total), 2) AS aov
FROM order_totals;
```

```text
╭────────╮
│  aov   │
╞════════╡
│ 548.65 │
╰────────╯
```

Now the query reads top-to-bottom like prose: "define order_totals; average it." That ordering is the whole point. A well-named CTE is a sentence of documentation that the engine verifies for you.

### Multi-CTE pipelines

`WITH` takes a comma-separated list of CTEs, and each one may reference the CTEs defined **before** it. That gives you a pipeline: raw data → step 1 → step 2 → result. This is how data engineers actually structure analytics.

Business question: what is monthly **gross revenue** (canonical: item revenue of non-cancelled orders), and how does each month compare to the previous one?

Step 1+2 first — per-order revenue tagged with its month, then rolled up by month:

```sql
WITH order_revenue AS (
    SELECT
        o.order_id,
        strftime('%Y-%m', o.ordered_at) AS month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
)
SELECT
    month,
    COUNT(*) AS orders,
    ROUND(SUM(item_revenue), 2) AS gross_revenue
FROM order_revenue
GROUP BY month
ORDER BY month DESC
LIMIT 6;
```

```text
╭─────────┬────────┬───────────────╮
│  month  │ orders │ gross_revenue │
╞═════════╪════════╪═══════════════╡
│ 2026-07 │    363 │     181073.95 │
│ 2026-06 │    570 │     288614.97 │
│ 2026-05 │    436 │     234748.78 │
│ 2026-04 │    346 │     194769.61 │
│ 2026-03 │    288 │     170011.09 │
│ 2026-02 │    217 │     118340.17 │
╰─────────┴────────┴───────────────╯
```

Now the full pipeline. To compare a month with its predecessor *without* window functions (they arrive in Module 6), join the monthly CTE **to itself**, shifting one month back with date arithmetic:

```sql
WITH order_revenue AS (
    SELECT
        o.order_id,
        strftime('%Y-%m', o.ordered_at) AS month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id
),
monthly AS (
    SELECT
        month,
        COUNT(*) AS orders,
        ROUND(SUM(item_revenue), 2) AS gross_revenue
    FROM order_revenue
    GROUP BY month
)
SELECT
    cur.month,
    cur.orders,
    cur.gross_revenue,
    prev.gross_revenue AS prev_revenue,
    ROUND(100.0 * (cur.gross_revenue - prev.gross_revenue) / prev.gross_revenue, 1) AS mom_pct
FROM monthly cur
LEFT JOIN monthly prev
    ON prev.month = strftime('%Y-%m', DATE(cur.month || '-01', '-1 month'))
WHERE cur.month >= '2026-01'
ORDER BY cur.month;
```

```text
╭─────────┬────────┬───────────────┬──────────────┬─────────╮
│  month  │ orders │ gross_revenue │ prev_revenue │ mom_pct │
╞═════════╪════════╪═══════════════╪══════════════╪═════════╡
│ 2026-01 │    201 │     128438.46 │    244602.36 │   -47.5 │
│ 2026-02 │    217 │     118340.17 │    128438.46 │    -7.9 │
│ 2026-03 │    288 │     170011.09 │    118340.17 │    43.7 │
│ 2026-04 │    346 │     194769.61 │    170011.09 │    14.6 │
│ 2026-05 │    436 │     234748.78 │    194769.61 │    20.5 │
│ 2026-06 │    570 │     288614.97 │    234748.78 │    22.9 │
│ 2026-07 │    363 │     181073.95 │    288614.97 │   -37.3 │
╰─────────┴────────┴───────────────┴──────────────┴─────────╯
```

Read the pipeline top-down: `order_revenue` (grain: one row per order) → `monthly` (grain: one row per month, *built from the previous CTE*) → final SELECT. Three things to study here:

- **A CTE can be referenced more than once.** The final SELECT reads `monthly` twice (`cur` and `prev`). A derived table would force you to paste the entire subquery twice — the single strongest argument for CTEs.
- The `LEFT JOIN` keeps the first month of history even though it has no predecessor (here every 2026 month has one; January's predecessor is 2025-12).
- The −47.5% January cliff after December, and July trailing June, are the seasonality DATASET.md promised (July is also only half over — the data ends 2026-07-14). Sanity-checking numbers against known reality is part of the job.

In Module 6, `LAG(gross_revenue) OVER (ORDER BY month)` will replace the self-join with one line — but the pipeline shape (clean grain per CTE, roll up, then compare) stays exactly the same, which is why we built it here.

### CTE vs derived table vs view

All three wrap a query and give it a table shape. Choosing:

- **Derived table** — fine for one small, obvious step. If it needs a comment or a second reference, promote it.
- **CTE** — the default for anything multi-step. Named, ordered, reusable within the query, and the top-down structure *is* the documentation. Zero cost to introduce.
- **View** — a named query stored *in the database*, shared across all queries and users. Right choice when a definition (e.g. "gross revenue") must be written once and reused everywhere. Views are DDL — we cover them properly in Module 8.

A CTE lives and dies with one statement; a view is the same idea made permanent.

> **PostgreSQL note:** In PostgreSQL 11 and earlier, CTEs were an "optimization fence" — always materialized, which could hurt performance. Since PostgreSQL 12 they are inlined into the outer query when safe, like SQLite does, and you can force either behavior with `WITH x AS MATERIALIZED (...)` / `NOT MATERIALIZED`. You'll still meet the old folklore ("CTEs are slow!") in code review — it's obsolete.

## 6. Set operations: UNION, INTERSECT, EXCEPT

Joins combine tables *sideways* (adding columns); set operations combine query results *vertically* (stacking or comparing rows). Both inputs must have the same number of columns with compatible types; column names come from the first SELECT; a trailing `ORDER BY` applies to the combined result.

**`UNION ALL`** stacks rows, keeping everything. **`UNION`** stacks and then **deduplicates** the combined result. Which countries does Nordkart touch, counting both customers and suppliers?

```sql
SELECT country FROM customers
UNION
SELECT country FROM suppliers
ORDER BY country;
```

```text
╭────────────────╮
│    country     │
╞════════════════╡
│ Austria        │
│ Denmark        │
│ Finland        │
│ France         │
│ Germany        │
│ Netherlands    │
│ Norway         │
│ Sweden         │
│ Switzerland    │
│ United Kingdom │
╰────────────────╯
```

Ten distinct countries. The same query with `UNION ALL` keeps every row — all 800 customer rows plus all 40 supplier rows:

```sql
SELECT COUNT(*) AS rows_kept
FROM (
    SELECT country FROM customers
    UNION ALL
    SELECT country FROM suppliers
);
```

```text
╭───────────╮
│ rows_kept │
╞═══════════╡
│       840 │
╰───────────╯
```

Default to `UNION ALL` unless you *specifically* want dedup — it says what you mean, and it's cheaper (dedup requires sorting or hashing the whole result). Choosing `UNION` casually is a genuine bug source; see Pitfalls.

**`INTERSECT`** keeps rows present in *both* inputs. Which customers were **active** (canonical: at least one non-cancelled order) in both 2025 and 2026 — our year-over-year retained base?

```sql
SELECT COUNT(*) AS loyal_customers
FROM (
    SELECT customer_id FROM orders
    WHERE status <> 'cancelled'
      AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01'
    INTERSECT
    SELECT customer_id FROM orders
    WHERE status <> 'cancelled'
      AND ordered_at >= '2026-01-01'
);
```

```text
╭─────────────────╮
│ loyal_customers │
╞═════════════════╡
│             380 │
╰─────────────────╯
```

**`EXCEPT`** keeps rows in the first input that are absent from the second — set difference, and a very natural anti-join. Marketing wants a re-engagement list: customers who opted in to marketing but have *not* been active in 2026:

```sql
SELECT COUNT(*) AS reengagement_targets
FROM (
    SELECT customer_id FROM customers
    WHERE marketing_opt_in = 1
    EXCEPT
    SELECT customer_id FROM orders
    WHERE status <> 'cancelled' AND ordered_at >= '2026-01-01'
);
```

```text
╭──────────────────────╮
│ reengagement_targets │
╞══════════════════════╡
│                  109 │
╰──────────────────────╯
```

Two properties worth memorizing: `INTERSECT` and `EXCEPT` deduplicate their result (like `UNION`), and — unlike `NOT IN` — set operations treat NULLs as equal to each other, so `EXCEPT` is NULL-safe.

> **PostgreSQL note:** PostgreSQL also offers `INTERSECT ALL` and `EXCEPT ALL` (duplicate-preserving variants). SQLite implements `ALL` only for `UNION`.

## 7. Recursive CTEs

Some questions are *iterative*: "walk this tree until you run out of children", "give me every date from A to B". `WITH RECURSIVE` is SQL's loop. Anatomy:

```
WITH RECURSIVE name AS (
    <anchor member>        -- runs once: the starting rows
    UNION ALL
    <recursive member>     -- references `name`: runs repeatedly on the
                           -- rows produced by the previous round,
                           -- until a round produces no rows
)
SELECT ... FROM name;
```

The smallest possible example — count to 5:

```sql
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 5
)
SELECT n FROM counter;
```

```text
╭───╮
│ n │
╞═══╡
│ 1 │
│ 2 │
│ 3 │
│ 4 │
│ 5 │
╰───╯
```

The anchor produces `1`. Round 1 of the recursive member sees `{1}` and produces `2`; round 2 sees `{2}` and produces `3`; … round 4 produces `5`; round 5 finds `n < 5` false, produces nothing, and recursion stops. **The termination condition lives in the recursive member's WHERE clause** — forget it and the query never ends (Pitfalls).

### Walking the category tree

`categories` is self-referencing: 6 top-level categories have `parent_category_id IS NULL`, 19 children point at their parents. No fixed number of self-joins can walk a tree of unknown depth — recursion can. Full paths with depth:

```sql
WITH RECURSIVE category_tree AS (
    SELECT category_id, name, 0 AS depth, name AS path
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, ct.depth + 1, ct.path || ' > ' || c.name
    FROM categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT category_id, depth, path
FROM category_tree
ORDER BY path
LIMIT 10;
```

```text
╭─────────────┬───────┬─────────────────────────╮
│ category_id │ depth │          path           │
╞═════════════╪═══════╪═════════════════════════╡
│          22 │     0 │ Apparel                 │
│          24 │     1 │ Apparel > Base Layers   │
│          25 │     1 │ Apparel > Gloves & Hats │
│          23 │     1 │ Apparel > Jackets       │
│           1 │     0 │ Camping                 │
│           5 │     1 │ Camping > Backpacks     │
│           4 │     1 │ Camping > Camp Kitchen  │
│           3 │     1 │ Camping > Sleeping Bags │
│           2 │     1 │ Camping > Tents         │
│           6 │     0 │ Climbing                │
╰─────────────┴───────┴─────────────────────────╯
```

(25 rows total — one per category.) The anchor selects the 6 roots at depth 0. Each round of the recursive member joins `categories` against the rows found so far, attaching children to their parents and extending `path`. Nordkart's tree is only 2 levels deep, but this exact query handles 10 levels unchanged — that's the point.

Termination here is *structural*: eventually no category has a parent in the newest rows, the join produces nothing, and recursion stops. That works **only because the data is an acyclic tree** — a cycle (A's parent is B, B's parent is A) would loop forever.

The most common production use of a tree walk is the **roll-up**: aggregate facts recorded at leaf level up to the top. Products attach to child categories only — so how big is each top-level category's catalog?

```sql
WITH RECURSIVE category_tree AS (
    SELECT category_id, name AS root_name
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, ct.root_name
    FROM categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
)
SELECT ct.root_name AS top_level_category, COUNT(p.product_id) AS products
FROM category_tree ct
JOIN products p ON p.category_id = ct.category_id
GROUP BY ct.root_name
ORDER BY products DESC;
```

```text
╭────────────────────┬──────────╮
│ top_level_category │ products │
╞════════════════════╪══════════╡
│ Camping            │       89 │
│ Climbing           │       62 │
│ Apparel            │       56 │
│ Hiking             │       51 │
│ Winter Sports      │       48 │
│ Water Sports       │       44 │
╰────────────────────┴──────────╯
```

Here the recursion carries `root_name` down to every descendant, producing a flat (category_id → top-level ancestor) mapping — then it's an ordinary join + GROUP BY.

### Generating a date series: the calendar spine

Watch what a naive daily report does with January 2023, Nordkart's very first (and quietest) month:

```sql
SELECT DATE(ordered_at) AS day, COUNT(*) AS orders
FROM orders
WHERE ordered_at >= '2023-01-01' AND ordered_at < '2023-02-01'
GROUP BY day
ORDER BY day;
```

```text
╭────────────┬────────╮
│    day     │ orders │
╞════════════╪════════╡
│ 2023-01-01 │      1 │
│ 2023-01-02 │      1 │
│ 2023-01-03 │      1 │
│ 2023-01-11 │      1 │
│ 2023-01-18 │      1 │
│ 2023-01-26 │      1 │
│ 2023-01-31 │      1 │
╰────────────┴────────╯
```

Seven rows for a 31-day month. `GROUP BY` can only group rows that *exist* — days with zero orders simply vanish. That's poison for time series: charts silently skip days, moving averages are computed over the wrong denominators, "days since last order" breaks. The fix is a **calendar spine**: a generated table with one row per calendar day, which the facts are LEFT JOINed onto. Data engineers build these constantly (daily, weekly, monthly spines) precisely because *the absence of data is itself data*.

A recursive CTE generates the spine:

```sql
WITH RECURSIVE calendar AS (
    SELECT DATE('2023-01-01') AS day
    UNION ALL
    SELECT DATE(day, '+1 day') FROM calendar WHERE day < '2023-03-31'
)
SELECT COUNT(*) AS days, MIN(day) AS first_day, MAX(day) AS last_day
FROM calendar;
```

```text
╭──────┬────────────┬────────────╮
│ days │ first_day  │  last_day  │
╞══════╪════════════╪════════════╡
│   90 │ 2023-01-01 │ 2023-03-31 │
╰──────┴────────────┴────────────╯
```

90 days, no gaps, by construction. Now LEFT JOIN the daily order counts onto it and keep the days that found no match — the zero-order days of Q1 2023:

```sql
WITH RECURSIVE calendar AS (
    SELECT DATE('2023-01-01') AS day
    UNION ALL
    SELECT DATE(day, '+1 day') FROM calendar WHERE day < '2023-03-31'
),
daily_orders AS (
    SELECT DATE(ordered_at) AS day, COUNT(*) AS orders
    FROM orders
    GROUP BY day
)
SELECT c.day
FROM calendar c
LEFT JOIN daily_orders d ON d.day = c.day
WHERE d.day IS NULL
ORDER BY c.day
LIMIT 10;
```

```text
╭────────────╮
│    day     │
╞════════════╡
│ 2023-01-04 │
│ 2023-01-05 │
│ 2023-01-06 │
│ 2023-01-07 │
│ 2023-01-08 │
│ 2023-01-09 │
│ 2023-01-10 │
│ 2023-01-12 │
│ 2023-01-13 │
│ 2023-01-14 │
╰────────────╯
```

(58 rows total — 58 of Q1 2023's 90 days had no orders at all.) Note the shape: recursive spine CTE + ordinary aggregation CTE + LEFT JOIN + `IS NULL` anti-join filter, all in one statement. `WITH RECURSIVE` happily mixes recursive and non-recursive CTEs in one list.

> **PostgreSQL note:** PostgreSQL has `generate_series('2023-01-01'::date, '2023-03-31'::date, '1 day')` — use it instead of a recursive spine; it's clearer and faster. The recursive technique remains worth knowing: it works everywhere, and trees still require it. PostgreSQL 14+ also adds `SEARCH` and `CYCLE` clauses to recursive CTEs for ordering tree output and detecting cycles declaratively.

## Pitfalls

### Pitfall 1: a correlated subquery re-executed per row

Question: which orders landed in Nordkart's busiest months? Intuitive first attempt — for each order, count the orders sharing its calendar month. Turn on the CLI timer first so you can see the cost:

```bash
sqlite3 -box shop.db
```

then inside the shell: `.timer on`, and run:

```sql
-- BAD: the correlated subquery re-runs for every one of the 6,000 orders,
-- and each run scans all 6,000 orders: ~36 million row visits
SELECT
    o.order_id,
    DATE(o.ordered_at) AS ordered_on,
    (SELECT COUNT(*)
     FROM orders o2
     WHERE strftime('%Y-%m', o2.ordered_at) = strftime('%Y-%m', o.ordered_at)) AS orders_that_month
FROM orders o
ORDER BY orders_that_month DESC, o.order_id
LIMIT 5;
```

```text
╭──────────┬────────────┬───────────────────╮
│ order_id │ ordered_on │ orders_that_month │
╞══════════╪════════════╪═══════════════════╡
│       11 │ 2026-06-13 │               596 │
│       20 │ 2026-06-21 │               596 │
│       22 │ 2026-06-15 │               596 │
│       42 │ 2026-06-28 │               596 │
│       44 │ 2026-06-19 │               596 │
╰──────────┴────────────┴───────────────────╯
Run Time: real 14.206657 user 14.183748 sys 0.000176
```

**14.2 seconds** on a 6,000-row table. The correlation compares *expressions* (`strftime` on both sides), which defeats SQLite's automatic-index rescue, so you get the true nested-loop cost. The answer is right; the plan is a disaster — and it scales quadratically.

The mechanical rewrite: compute each group **once** in a CTE, then join.

```sql
WITH monthly AS (
    SELECT strftime('%Y-%m', ordered_at) AS month, COUNT(*) AS orders_that_month
    FROM orders
    GROUP BY month
)
SELECT
    o.order_id,
    DATE(o.ordered_at) AS ordered_on,
    m.orders_that_month
FROM orders o
JOIN monthly m ON m.month = strftime('%Y-%m', o.ordered_at)
ORDER BY m.orders_that_month DESC, o.order_id
LIMIT 5;
```

```text
╭──────────┬────────────┬───────────────────╮
│ order_id │ ordered_on │ orders_that_month │
╞══════════╪════════════╪═══════════════════╡
│       11 │ 2026-06-13 │               596 │
│       20 │ 2026-06-21 │               596 │
│       22 │ 2026-06-15 │               596 │
│       42 │ 2026-06-28 │               596 │
│       44 │ 2026-06-19 │               596 │
╰──────────┴────────────┴───────────────────╯
Run Time: real 0.005507 user 0.005495 sys 0.000000
```

Identical output, **5.5 milliseconds** — about 2,500× faster, because `monthly` is computed in one scan (43 groups) and joined back. Whenever a correlated subquery aggregates *per group* rather than looking up a single row by key, this GROUP-BY-then-join rewrite applies.

### Pitfall 2: a scalar subquery that returns more than one row

You want products pricier than tents, and you write this without thinking hard about how many rows the subquery yields:

```sql
-- BAD: the subquery returns 23 rows (one per tent), not one value —
-- SQLite silently keeps only the FIRST row and discards the rest
SELECT COUNT(*) AS pricier_than_a_tent
FROM products
WHERE unit_price > (SELECT unit_price FROM products WHERE category_id = 2);
```

```text
╭─────────────────────╮
│ pricier_than_a_tent │
╞═════════════════════╡
│                 201 │
╰─────────────────────╯
```

No error — and that's the trap. Category 2 (Tents) has 23 products; SQLite quietly used whichever row came first in scan order:

```sql
SELECT unit_price FROM products WHERE category_id = 2 LIMIT 3;
```

```text
╭────────────╮
│ unit_price │
╞════════════╡
│      698.9 │
│     604.87 │
│     111.33 │
╰────────────╯
```

So the comparison ran against 698.90 — an arbitrary threshold that can change if the physical row order changes. The number 201 is meaningless.

> **PostgreSQL note:** PostgreSQL refuses to guess: the same query fails at runtime with `ERROR: more than one row returned by a subquery used as an expression`. Painful, but far safer than SQLite's silent first-row pick.

The fix is to make the intent explicit with an aggregate (or `LIMIT 1` with an `ORDER BY`, if "first" genuinely means something). "Pricier than *every* tent":

```sql
SELECT COUNT(*) AS pricier_than_every_tent
FROM products
WHERE unit_price > (SELECT MAX(unit_price) FROM products WHERE category_id = 2);
```

```text
╭─────────────────────────╮
│ pricier_than_every_tent │
╞═════════════════════════╡
│                       7 │
╰─────────────────────────╯
```

Discipline: every scalar subquery you write should be *provably* single-row — an aggregate without GROUP BY, a lookup on a unique key, or an explicit `LIMIT 1`.

### Pitfall 3: UNION deduplicating when you wanted UNION ALL

Finance asks for total captured revenue across card and PayPal. Someone stacks the two amount lists with `UNION` because it "combines results":

```sql
-- BAD: UNION deduplicates — every repeated amount (two 49.90 payments,
-- a card payment equal to a paypal payment...) is collapsed to one row
SELECT COUNT(*) AS payment_rows, ROUND(SUM(amount), 2) AS revenue
FROM (
    SELECT amount FROM payments WHERE status = 'captured' AND method = 'card'
    UNION
    SELECT amount FROM payments WHERE status = 'captured' AND method = 'paypal'
);
```

```text
╭──────────────┬────────────╮
│ payment_rows │  revenue   │
╞══════════════╪════════════╡
│         3366 │ 1948048.19 │
╰──────────────┴────────────╯
```

With `UNION ALL`:

```sql
SELECT COUNT(*) AS payment_rows, ROUND(SUM(amount), 2) AS revenue
FROM (
    SELECT amount FROM payments WHERE status = 'captured' AND method = 'card'
    UNION ALL
    SELECT amount FROM payments WHERE status = 'captured' AND method = 'paypal'
);
```

```text
╭──────────────┬────────────╮
│ payment_rows │  revenue   │
╞══════════════╪════════════╡
│         3743 │ 2035569.26 │
╰──────────────┴────────────╯
```

`UNION` silently swallowed 377 payment rows and **€87,521.07 of revenue** — no warning, no error, just a wrong number that looks plausible. Two payments of the same amount are distinct real-world events; deduplicating them is data loss. And even when duplicates are impossible, `UNION` still pays the sort/hash cost of checking. Default to `UNION ALL`; write `UNION` only when deduplication is the *requirement*. (Here, of course, the honest query needs no set operation at all: `WHERE method IN ('card', 'paypal')`.)

### Pitfall 4: a recursive CTE with no termination condition

The `counter` example stopped because of `WHERE n < 5` in the recursive member. Remove the condition and every round produces a new row forever. This is safe to *demonstrate* only because an outer `LIMIT` acts as a guard — SQLite produces recursive rows lazily, so it stops asking once it has 5:

```sql
-- BAD: no WHERE in the recursive member — nothing ever stops this;
-- only the outer LIMIT 5 saves us from an infinite loop
WITH RECURSIVE forever(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM forever
)
SELECT n FROM forever LIMIT 5;
```

```text
╭───╮
│ n │
╞═══╡
│ 1 │
│ 2 │
│ 3 │
│ 4 │
│ 5 │
╰───╯
```

Remove the `LIMIT` and this query runs until you kill it. **Do not rely on the LIMIT trick** — it works only when the outer query can stream rows directly; add an `ORDER BY`, a join, or an aggregate on top and the engine must exhaust the (infinite) CTE first. The same failure hits tree walks when the data contains a **cycle**: the join-based termination of `category_tree` assumes an acyclic tree, and one corrupted `parent_category_id` pointing at a descendant loops forever.

Defensive pattern — carry a depth counter and bound it:

```sql
WITH RECURSIVE category_tree AS (
    SELECT category_id, name, 0 AS depth
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_category_id = ct.category_id
    WHERE ct.depth < 10          -- guard: no sane category tree is 10 deep
)
SELECT COUNT(*) AS categories_reached, MAX(depth) AS max_depth
FROM category_tree;
```

```text
╭────────────────────┬───────────╮
│ categories_reached │ max_depth │
╞════════════════════╪═══════════╡
│                 25 │         1 │
╰────────────────────┴───────────╯
```

On healthy data the guard never fires (all 25 categories reached, max depth 1); on cyclic data it converts an infinite loop into a bounded, debuggable result.

## Exercises

No answers here — solutions live in `solutions/05-subqueries-and-ctes.md`. Use the canonical metric definitions from DATASET.md throughout.

**Warm-up**

1. *Pricing sanity check.* In a single query, report the average catalog list price and how many products are priced above it. (Two scalar subqueries.)
2. *Merchandising request.* List the five most expensive products anywhere under the **Water Sports** top-level category — name and price. Do not hard-code any category ids. (`IN` + a nested scalar subquery.)
3. *Deduplication awareness.* City names appear in both `customers.city` and `addresses.city`. How many rows do you get when you stack the two columns with `UNION ALL`, and how many distinct city names when you use `UNION`? Report both numbers in one query.

**Core**

4. *Premium products.* Which products are priced at least 25% above their own category's average price? Show name, category name, price, and the category average; return the 10 most expensive. Also determine how many products qualify in total. (Correlated scalar subquery.)
5. *Lapsed customers.* How many customers were active in 2025 (placed at least one non-cancelled order) but have not been active in 2026 so far? (`EXCEPT`.)
6. *AOV by country.* Compute AOV (canonical definition) per customer country, with the number of non-cancelled orders per country, highest AOV first. (CTE pipeline: order totals → join customers → aggregate.)
7. *Catalog feed.* The web team needs every product with its sku, name, and full category path in the form `Camping > Tents`. Build it with a recursive CTE and show the first 5 rows ordered by sku.
8. *Ops gap check.* Which calendar days in 2025 had **zero** orders? List the dates. (Recursive calendar spine + anti-join.)

**Challenge**

9. *Seasonality profile.* For 2025, produce each month's gross revenue and its share of the full-year total as a percentage. (Multi-CTE pipeline; the year total must come from a CTE or scalar subquery, not a hand-typed constant.)
10. *Worst crashes.* Across all of Nordkart's history, find the three worst month-over-month gross-revenue drops (by percentage). Show month, revenue, previous month's revenue, and the percentage change. (Self-join of a monthly CTE.)
11. *Board slide.* All-time gross revenue by **top-level** category (Camping, Climbing, ...), highest first. Remember products attach only to child categories. (Recursive roll-up + canonical item revenue.)
12. *First-purchase cohorts.* For each year, how many customers placed their first-ever non-cancelled order in that year? (CTE with a per-customer MIN, then aggregate — a preview of the cohort analysis coming in Module 11.)

## Key takeaways

- **Scalar subquery** `(SELECT ...)` → one row, one column; usable anywhere a value fits. Make single-row-ness *provable* (aggregate, unique-key lookup, or `LIMIT 1`) — SQLite silently takes the first row of a multi-row result; PostgreSQL errors.
- **Correlated** subqueries reference outer-query columns and conceptually re-run per row. Fine for indexed key lookups; for per-group aggregates, rewrite as GROUP BY in a CTE + join (2,500× in our demo).
- `IN (subquery)` = membership test / semi-join; still never `NOT IN` with nullable subqueries — use `NOT EXISTS`.
- **Derived table** = subquery in FROM (alias required); the tool for aggregating an aggregate.
- **CTE**: `WITH step1 AS (...), step2 AS (...) SELECT ...` — later CTEs and the final SELECT can reference earlier CTEs, and can reference one CTE multiple times. Default structure for multi-step analysis; views (Module 8) make a definition permanent.
- **Set ops** stack rows: `UNION ALL` (keep all — the default choice), `UNION` / `INTERSECT` / `EXCEPT` (deduplicate; NULL-safe, unlike `NOT IN`). Same column count, compatible types, names from the first SELECT.
- **`WITH RECURSIVE`** = anchor `UNION ALL` recursive member; termination lives in the recursive member's WHERE (explicit bound, or a join that runs dry on acyclic data). Belt-and-braces: carry a `depth` column and bound it.
- **Calendar spine**: generate every date, LEFT JOIN facts onto it — because GROUP BY cannot show you the days that aren't there. In PostgreSQL, `generate_series` does this natively.
