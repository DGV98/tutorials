# Module 4 — Joins

Almost no real question about a business can be answered from a single table. "Which customers stopped ordering?" needs `customers` and `orders`. "What did we earn per category?" needs four tables. Joins are how SQL reassembles data that was deliberately split apart — and they are where most real-world SQL bugs live. A data engineer who deeply understands join semantics (and the fan-out pitfall in particular) ships correct numbers; one who doesn't ships revenue reports that are silently wrong by 2x.

This module runs read-only queries against `shop.db` — no copy needed. Open a session from the course root with `sqlite3 -box shop.db` and follow along; every query below is shown with the output it actually produces.

## What you'll learn

- The row-matching mental model behind every join
- `INNER JOIN` with `ON`, table aliases, and the `USING` shorthand
- `LEFT JOIN`, and the canonical "find rows with no match" (anti-join) pattern
- `RIGHT` and `FULL OUTER JOIN` — what they do and why `LEFT` is the everyday idiom
- `CROSS JOIN` and its legitimate uses (grids and scaffolds)
- Self-joins: a table joined to itself (category trees, pairs of orders)
- Chaining 4–6 tables along foreign keys, and combining joins with `GROUP BY`
- Semi-joins (`EXISTS`, `IN`) and anti-joins (`NOT EXISTS`, `LEFT ... IS NULL`)
- Join conditions beyond `=`: range joins
- The four join pitfalls that produce silently wrong numbers: fan-out, accidental cross joins, `WHERE` that kills a `LEFT JOIN`, and `NOT IN` with NULLs

## 4.1 Why your data lives in more than one table

Look at a single order:

```sql
SELECT order_id, customer_id, address_id, status, ordered_at
FROM orders
WHERE order_id = 4001;
```

```text
╭──────────┬─────────────┬────────────┬───────────┬─────────────────────╮
│ order_id │ customer_id │ address_id │  status   │     ordered_at      │
╞══════════╪═════════════╪════════════╪═══════════╪═════════════════════╡
│     4001 │         516 │        727 │ delivered │ 2026-06-30 05:00:35 │
╰──────────┴─────────────┴────────────┴───────────┴─────────────────────╯
```

The row doesn't say *who* customer 516 is. It only carries a reference — a **foreign key** pointing at the `customers` table. That's deliberate. If every order row repeated the customer's name, email, and city, then a customer changing their email would require updating thousands of order rows, and any row you missed would disagree with the rest. Storing each fact exactly once and referencing it by key is called **normalization**; Module 7 covers the theory. The cost of normalization is that reading the data back requires reassembly. That reassembly operation is the join.

## 4.2 INNER JOIN: the row-matching mental model

The mental model that makes every join predictable:

1. Conceptually, start with every possible **pair** of rows — one from the left table, one from the right (the Cartesian product).
2. The `ON` condition is a filter over those pairs: keep the pairs where it's TRUE, discard the rest.
3. Each surviving pair becomes one output row containing the columns of *both* tables.

Real engines don't materialize the full product — they use smarter algorithms — but the *result* is always as if they had. Let's resolve order 4001's customer:

```sql
SELECT
    o.order_id,
    o.ordered_at,
    o.status,
    c.first_name,
    c.last_name,
    c.country
FROM orders AS o
INNER JOIN customers AS c
    ON c.customer_id = o.customer_id
WHERE o.order_id = 4001;
```

```text
╭──────────┬─────────────────────┬───────────┬────────────┬───────────┬─────────╮
│ order_id │     ordered_at      │  status   │ first_name │ last_name │ country │
╞══════════╪═════════════════════╪═══════════╪════════════╪═══════════╪═════════╡
│     4001 │ 2026-06-30 05:00:35 │ delivered │ Ulf        │ Schmidt   │ Norway  │
╰──────────┴─────────────────────┴───────────┴────────────┴───────────┴─────────╯
```

Three things to internalize:

- **Table aliases** (`orders AS o`) are near-mandatory in join queries. They keep the query readable and they resolve ambiguity: both tables have a `customer_id`, so a bare `customer_id` in the SELECT list would be an error (or worse, a guess). Qualify every column in a multi-table query, always — future readers (including you) shouldn't have to memorize which table owns which column.
- `INNER JOIN` keeps **only matched pairs**. An order with no matching customer, or a customer with no matching order, produces nothing.
- The bare keyword `JOIN` means `INNER JOIN`. From here on we write `JOIN`, as almost everyone does.

A real business question — who placed the five most recent orders?

```sql
SELECT
    o.order_id,
    o.ordered_at,
    c.first_name || ' ' || c.last_name AS customer,
    c.country
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
ORDER BY o.ordered_at DESC
LIMIT 5;
```

```text
╭──────────┬─────────────────────┬─────────────────┬────────────────╮
│ order_id │     ordered_at      │    customer     │    country     │
╞══════════╪═════════════════════╪═════════════════╪════════════════╡
│     4481 │ 2026-07-14 21:44:48 │ Saga Bergstrom  │ Denmark        │
│     2693 │ 2026-07-14 21:03:53 │ Oskar Bergstrom │ Netherlands    │
│     1357 │ 2026-07-14 20:13:11 │ Tobias Kron     │ Norway         │
│     3745 │ 2026-07-14 19:00:34 │ Mette Moller    │ United Kingdom │
│     2669 │ 2026-07-14 18:28:06 │ Lea Nyström     │ Germany        │
╰──────────┴─────────────────────┴─────────────────┴────────────────╯
```

Note the grain: this result has **one row per order**, decorated with customer attributes. Watching what one output row *means* — its grain — is the single most useful habit in join queries. It's about to matter a lot.

### ON vs USING

When the join column has the **same name on both sides**, `USING` is a shorthand:

```sql
SELECT order_id, ordered_at, country
FROM orders
JOIN customers USING (customer_id)
ORDER BY ordered_at DESC
LIMIT 3;
```

```text
╭──────────┬─────────────────────┬─────────────╮
│ order_id │     ordered_at      │   country   │
╞══════════╪═════════════════════╪═════════════╡
│     4481 │ 2026-07-14 21:44:48 │ Denmark     │
│     2693 │ 2026-07-14 21:03:53 │ Netherlands │
│     1357 │ 2026-07-14 20:13:11 │ Norway      │
╰──────────┴─────────────────────┴─────────────╯
```

`USING (customer_id)` means `ON` equality of that column, and it **merges** the column: the result has a single `customer_id`, referable without a table prefix. It only works when the names match exactly. `ON` is more general — it takes any boolean expression, which we'll exploit in section 4.9. There is also `NATURAL JOIN` (join on *all* same-named columns automatically); avoid it — adding a column to a table later can silently change what a natural join matches on.

> **PostgreSQL note:** `ON`, `USING`, and `NATURAL` work identically in PostgreSQL. The advice is the same there: `ON` or `USING`, never `NATURAL`.

## 4.3 LEFT JOIN: keep every row on the left

`INNER JOIN` drops unmatched rows. Often that's exactly wrong: "orders per customer" must not silently omit customers with zero orders. `LEFT JOIN` (fully: `LEFT OUTER JOIN`) keeps **every row of the left table**; where no right-table row matches, the right table's columns come back as NULL.

Customer 1 has never ordered; customer 2 has ordered twice:

```sql
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    o.order_id,
    o.status,
    o.ordered_at
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
WHERE c.customer_id IN (1, 2)
ORDER BY c.customer_id, o.ordered_at;
```

```text
╭─────────────┬────────────┬───────────┬──────────┬───────────┬─────────────────────╮
│ customer_id │ first_name │ last_name │ order_id │  status   │     ordered_at      │
╞═════════════╪════════════╪═══════════╪══════════╪═══════════╪═════════════════════╡
│           1 │ Hiro       │ Fisker    │          │           │                     │
│           2 │ Tobias     │ Ek        │     1094 │ delivered │ 2024-03-16 20:06:46 │
│           2 │ Tobias     │ Ek        │     2230 │ delivered │ 2026-06-10 02:55:32 │
╰─────────────┴────────────┴───────────┴──────────┴───────────┴─────────────────────╯
```

Hiro Fisker survives with NULLs in every `orders` column (blank cells in box output). That NULL-padded row is the signature of a left-table row with no match — and it powers one of the most-used patterns in all of SQL.

### The canonical "no match" pattern (anti-join)

**Which customers have never placed an order?** LEFT JOIN, then keep only the NULL-padded rows:

```sql
SELECT COUNT(*) AS customers_without_orders
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```

```text
╭──────────────────────────╮
│ customers_without_orders │
╞══════════════════════════╡
│                      125 │
╰──────────────────────────╯
```

125 of Nordkart's 800 customers created an account and never bought anything. Test the NULL on a **NOT NULL column of the right table** — `o.order_id` is the primary key, so it can only be NULL because the join failed to match, never because the data itself contains a NULL. Who are the longest-standing ones?

```sql
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer,
    c.country,
    c.created_at
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.created_at
LIMIT 5;
```

```text
╭─────────────┬────────────────┬─────────┬─────────────────────╮
│ customer_id │    customer    │ country │     created_at      │
╞═════════════╪════════════════╪═════════╪═════════════════════╡
│         546 │ Leif Andersson │ Finland │ 2022-01-14 16:33:32 │
│         465 │ Mats Kron      │ Austria │ 2022-01-15 11:46:52 │
│         732 │ Otto Vik       │ Austria │ 2022-02-05 08:38:12 │
│         208 │ Hedda Duarte   │ Finland │ 2022-02-08 03:33:23 │
│         400 │ Yusuf Sandberg │ Norway  │ 2022-02-15 04:24:14 │
╰─────────────┴────────────────┴─────────┴─────────────────────╯
```

Same pattern, catalog side — **products that have never sold**:

```sql
SELECT COUNT(*) AS products_never_sold
FROM products AS p
LEFT JOIN order_items AS oi
    ON oi.product_id = p.product_id
WHERE oi.order_id IS NULL;
```

```text
╭─────────────────────╮
│ products_never_sold │
╞═════════════════════╡
│                  41 │
╰─────────────────────╯
```

41 products are taking up warehouse space with zero sales — exactly the kind of number a merchandising team asks for weekly. Choosing which table goes on the left is choosing the question: "every **customer**, with orders if any" vs "every **order**, with its customer". Put the table whose rows must all survive on the left.

## 4.4 RIGHT and FULL OUTER JOIN

`RIGHT JOIN` is `LEFT JOIN` with the roles swapped: keep every row of the *right* table. These two queries are the same query:

```sql
SELECT COUNT(*) AS row_count
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id;
```

```text
╭───────────╮
│ row_count │
╞═══════════╡
│      6125 │
╰───────────╯
```

```sql
SELECT COUNT(*) AS row_count
FROM orders AS o
RIGHT JOIN customers AS c
    ON o.customer_id = c.customer_id;
```

```text
╭───────────╮
│ row_count │
╞═══════════╡
│      6125 │
╰───────────╯
```

6,125 = 6,000 matched order rows + 125 NULL-padded rows for the order-less customers. Since any `RIGHT JOIN` can be rewritten as a `LEFT JOIN` by swapping the table order, almost everyone standardizes on `LEFT` — queries read top-to-bottom as "start from the table I care about, attach the rest". You'll encounter `RIGHT JOIN` mostly in other people's code.

> **PostgreSQL note:** PostgreSQL has supported `RIGHT` and `FULL OUTER JOIN` forever. SQLite added them in 3.39 (2022) — anything older only has `LEFT`.

`FULL OUTER JOIN` keeps unmatched rows from **both** sides. Inside one well-constrained database it's rarely needed (foreign keys guarantee an order always has a customer), but it shines when comparing two independently produced row sets. Business question: **of our buyers, who lapsed after 2025, who is new in 2026, and who was retained?** Compare the set of 2025 buyers with the set of 2026 buyers:

```sql
SELECT
    SUM(CASE WHEN y26.customer_id IS NULL THEN 1 ELSE 0 END) AS lapsed,
    SUM(CASE WHEN y25.customer_id IS NULL THEN 1 ELSE 0 END) AS new_in_2026,
    SUM(CASE WHEN y25.customer_id IS NOT NULL
              AND y26.customer_id IS NOT NULL THEN 1 ELSE 0 END) AS retained
FROM (SELECT DISTINCT customer_id FROM orders
      WHERE status <> 'cancelled'
        AND ordered_at >= '2025-01-01' AND ordered_at < '2026-01-01') AS y25
FULL JOIN (SELECT DISTINCT customer_id FROM orders
           WHERE status <> 'cancelled'
             AND ordered_at >= '2026-01-01') AS y26
    ON y26.customer_id = y25.customer_id;
```

```text
╭────────┬─────────────┬──────────╮
│ lapsed │ new_in_2026 │ retained │
╞════════╪═════════════╪══════════╡
│    117 │         148 │      380 │
╰────────┴─────────────┴──────────╯
```

The parenthesized `SELECT`s in the `FROM` clause are **derived tables** — inline, temporary tables. Module 5 treats them properly; for now read them as "build each year's buyer list first, then join the lists". A row with `y26.customer_id IS NULL` is a 2025 buyer with no 2026 match (lapsed); NULL on the `y25` side means new; NULL on neither means retained. Only a FULL join can show all three groups at once. (The conditional `SUM(CASE ...)` counting is Module 3's conditional aggregation.)

## 4.5 CROSS JOIN

`CROSS JOIN` is the raw Cartesian product — every left row paired with every right row, no `ON` at all:

```sql
SELECT COUNT(*) AS combinations
FROM customers
CROSS JOIN products;
```

```text
╭──────────────╮
│ combinations │
╞══════════════╡
│       280000 │
╰──────────────╯
```

800 × 350 = 280,000 rows. Usually a cross join is an accident (see Pitfalls). Its legitimate use is building an **exhaustive grid** when you must report *all* combinations — including ones with no data. Suppose operations wants a carrier × order-status coverage matrix. A plain join would only produce combinations that occur; the cross join produces them all:

```sql
SELECT ca.carrier, st.status
FROM (SELECT DISTINCT carrier FROM shipments) AS ca
CROSS JOIN (SELECT DISTINCT status FROM orders) AS st
ORDER BY ca.carrier, st.status
LIMIT 8;
```

```text
╭─────────┬───────────╮
│ carrier │  status   │
╞═════════╪═══════════╡
│ Bring   │ cancelled │
│ Bring   │ delivered │
│ Bring   │ paid      │
│ Bring   │ pending   │
│ Bring   │ returned  │
│ Bring   │ shipped   │
│ DHL     │ cancelled │
│ DHL     │ delivered │
╰─────────┴───────────╯
```

... 30 rows total (5 carriers × 6 statuses). The production pattern is: CROSS JOIN builds the complete scaffold, then a LEFT JOIN attaches actual counts so empty combinations show as 0 instead of vanishing. The same trick with a calendar table — a **date spine** — is how you make time series include zero-activity days; that's a Module 11 workhorse.

## 4.6 Self-joins

Nothing says the two sides of a join must be different tables. A **self-join** joins a table to itself under two aliases — the aliases are what make it possible, since each side needs a distinct name.

`categories` is a tree: each row may point at a parent row *in the same table*. To show each category next to its parent's name:

```sql
SELECT
    child.name  AS category,
    parent.name AS parent_category
FROM categories AS child
LEFT JOIN categories AS parent
    ON parent.category_id = child.parent_category_id
ORDER BY parent.name, child.name
LIMIT 10;
```

```text
╭───────────────┬─────────────────╮
│   category    │ parent_category │
╞═══════════════╪═════════════════╡
│ Apparel       │                 │
│ Camping       │                 │
│ Climbing      │                 │
│ Hiking        │                 │
│ Water Sports  │                 │
│ Winter Sports │                 │
│ Base Layers   │ Apparel         │
│ Gloves & Hats │ Apparel         │
│ Jackets       │ Apparel         │
│ Backpacks     │ Camping         │
╰───────────────┴─────────────────╯
```

... 25 rows total. Two details: the join is `LEFT` because the six top-level categories have `parent_category_id IS NULL` — an INNER join would silently drop them. And they appear first because SQLite sorts NULLs before values in ascending order (Module 1). Walking the *whole* tree (grandchildren, arbitrary depth) needs a recursive CTE — Module 5.

Self-joins also find **pairs of rows**. Business question: how often does a customer place two orders on the same day (a possible signal of "forgot an item, ordered again")?

```sql
SELECT
    o1.customer_id,
    o1.order_id AS order_a,
    o2.order_id AS order_b,
    date(o1.ordered_at) AS order_day
FROM orders AS o1
JOIN orders AS o2
    ON o2.customer_id = o1.customer_id
   AND o2.order_id > o1.order_id
   AND date(o2.ordered_at) = date(o1.ordered_at)
ORDER BY order_day DESC
LIMIT 5;
```

```text
╭─────────────┬─────────┬─────────┬────────────╮
│ customer_id │ order_a │ order_b │ order_day  │
╞═════════════╪═════════╪═════════╪════════════╡
│         104 │     525 │    1528 │ 2026-07-14 │
│         104 │     525 │    2693 │ 2026-07-14 │
│          21 │    1416 │    4938 │ 2026-07-14 │
│         104 │    1528 │    2693 │ 2026-07-14 │
│         420 │    1602 │    2669 │ 2026-07-14 │
╰─────────────┴─────────┴─────────┴────────────╯
```

```sql
SELECT COUNT(*) AS same_day_pairs
FROM orders AS o1
JOIN orders AS o2
    ON o2.customer_id = o1.customer_id
   AND o2.order_id > o1.order_id
   AND date(o2.ordered_at) = date(o1.ordered_at);
```

```text
╭────────────────╮
│ same_day_pairs │
╞════════════════╡
│            189 │
╰────────────────╯
```

The crucial trick is `o2.order_id > o1.order_id`. Without it every pair appears twice — (525, 1528) and (1528, 525) — and every order pairs with *itself*. Requiring a strict `>` on the key keeps exactly one representative per pair. One caution about *meaning*: `>` on the id deduplicates, but it does **not** imply `order_a` happened first — in this dataset order ids are not assigned in time order. When "which came first" matters, compare timestamps, not ids (an exercise below does exactly this).

## 4.7 Joining four, five, six tables

Real analytical queries routinely chain many tables. Each `JOIN` bolts one more table onto the working result, so build the chain by following the foreign keys and add one link at a time. The full picture of one order — buyer, products, categories:

```sql
SELECT
    o.order_id,
    c.first_name || ' ' || c.last_name AS customer,
    cat.name AS category,
    p.name AS product,
    oi.quantity,
    oi.unit_price,
    oi.discount_pct
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
JOIN order_items AS oi
    ON oi.order_id = o.order_id
JOIN products AS p
    ON p.product_id = oi.product_id
JOIN categories AS cat
    ON cat.category_id = p.category_id
WHERE o.order_id = 85;
```

```text
╭──────────┬───────────────┬────────────┬──────────────────┬──────────┬────────────┬──────────────╮
│ order_id │   customer    │  category  │     product      │ quantity │ unit_price │ discount_pct │
╞══════════╪═══════════════╪════════════╪══════════════════╪══════════╪════════════╪══════════════╡
│       85 │ Rune Karlsson │ Dry Bags   │ Aqua Dry Bag 40L │        1 │      54.81 │            0 │
│       85 │ Rune Karlsson │ Harnesses  │ Via Harness      │        1 │     125.14 │            0 │
│       85 │ Rune Karlsson │ Dry Bags   │ Seal Phone Case  │        1 │      24.89 │            0 │
│       85 │ Rune Karlsson │ Navigation │ True GPS Unit    │        1 │     285.11 │            0 │
╰──────────┴───────────────┴────────────┴──────────────────┴──────────┴────────────┴──────────────╯
```

Track the grain as each join lands: `orders` → still one row (one order); `+ customers` → still one row (a customer has exactly one row — joining "up" a foreign key never multiplies rows); `+ order_items` → **four rows**, because the order has four items (joining "down" to a child table multiplies rows by the number of children); `+ products`, `+ categories` → still four (up the keys again). The result's grain is *order line*, and order-level values like `o.shipping_cost` would now appear four times. Holding onto that fact is what saves you from the fan-out pitfall below.

### Joins + GROUP BY

Join to reach the columns, group to aggregate them. **Gross revenue per customer country for 2025** — using the canonical definitions (item revenue = `quantity * unit_price * (1 - discount_pct / 100.0)`; gross revenue excludes cancelled orders):

```sql
SELECT
    c.country,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_revenue
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2026-01-01'
GROUP BY c.country
ORDER BY gross_revenue DESC
LIMIT 5;
```

```text
╭─────────────┬────────┬───────────────╮
│   country   │ orders │ gross_revenue │
╞═════════════╪════════╪═══════════════╡
│ Sweden      │    603 │      338626.1 │
│ Germany     │    272 │     153458.23 │
│ Denmark     │    245 │     135606.42 │
│ Norway      │    213 │     112991.59 │
│ Netherlands │    165 │     104306.96 │
╰─────────────┴────────┴───────────────╯
```

The joined rows are at order-line grain, and that's fine for `SUM` here because item revenue *is* a line-level fact — summing lines is exactly right. But counting orders needs `COUNT(DISTINCT o.order_id)`: a plain `COUNT(o.order_id)` would count each order once per line. Whenever you aggregate above the grain of the joined result, ask of every aggregate: "is this measure repeated across the joined rows?"

## 4.8 Semi-joins and anti-joins

Often you don't want the other table's *columns* at all — you only want to know whether a matching row **exists**. That's a **semi-join**. Its negation — keep rows where no match exists — is an **anti-join** (you already met its LEFT JOIN form in 4.3).

**How many customers are active in 2026?** (Canonical definition: placed at least one non-cancelled order in the period.)

```sql
SELECT COUNT(*) AS active_customers_2026
FROM customers AS c
WHERE EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
      AND o.status <> 'cancelled'
      AND o.ordered_at >= '2026-01-01'
);
```

```text
╭───────────────────────╮
│ active_customers_2026 │
╞═══════════════════════╡
│                   528 │
╰───────────────────────╯
```

`EXISTS` asks, for each customer row, "does at least one such order exist?" — TRUE or FALSE, nothing more. The `SELECT 1` is conventional; `EXISTS` ignores what the inner query selects. The `IN` form reads differently but answers the same question:

```sql
SELECT COUNT(*) AS active_customers_2026
FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM orders
    WHERE status <> 'cancelled'
      AND ordered_at >= '2026-01-01'
);
```

```text
╭───────────────────────╮
│ active_customers_2026 │
╞═══════════════════════╡
│                   528 │
╰───────────────────────╯
```

Why prefer a semi-join over `JOIN` + `DISTINCT`? Because a join would produce one row per matching *order* (a customer with 24 orders appears 24 times) and you'd have to deduplicate after the fact. The semi-join never multiplies rows — each customer appears at most once, by construction — and it states your intent: "I'm filtering customers, not combining tables." (These are our first real subqueries; Module 5 explores them fully.)

The anti-join as `NOT EXISTS` — products that never sold, again:

```sql
SELECT COUNT(*) AS products_never_sold
FROM products AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items AS oi
    WHERE oi.product_id = p.product_id
);
```

```text
╭─────────────────────╮
│ products_never_sold │
╞═════════════════════╡
│                  41 │
╰─────────────────────╯
```

Same 41 as the `LEFT JOIN ... IS NULL` version. You now know three anti-join spellings:

| form | verdict |
|---|---|
| `NOT EXISTS (correlated subquery)` | safest, clearest intent — default choice |
| `LEFT JOIN ... WHERE right.pk IS NULL` | fine; classic; slightly more mechanism on display |
| `NOT IN (subquery)` | **booby-trapped** — breaks the moment the subquery returns a NULL; see Pitfall 4 |

> **PostgreSQL note:** in PostgreSQL, `NOT EXISTS` is also the safe, optimizer-friendly anti-join; `NOT IN` with a nullable subquery column has the exact same trap there — this is standard SQL three-valued logic, not a SQLite quirk.

## 4.9 Join conditions beyond equality

`ON` accepts any boolean expression, not just `a = b`. Ranges are the classic case. `price_history` stores each product's price as validity intervals (`valid_from`, `valid_to`, NULL = still current). **Did we actually charge order 85's customer the list price in effect on the order date?** Join each order line to the price row whose interval *contains* the order timestamp:

```sql
SELECT
    oi.order_id,
    o.ordered_at,
    oi.product_id,
    oi.unit_price AS price_charged,
    ph.price      AS list_price_then
FROM order_items AS oi
JOIN orders AS o
    ON o.order_id = oi.order_id
JOIN price_history AS ph
    ON ph.product_id = oi.product_id
   AND o.ordered_at >= ph.valid_from
   AND (ph.valid_to IS NULL OR o.ordered_at < ph.valid_to)
WHERE oi.order_id = 85
ORDER BY oi.product_id;
```

```text
╭──────────┬─────────────────────┬────────────┬───────────────┬─────────────────╮
│ order_id │     ordered_at      │ product_id │ price_charged │ list_price_then │
╞══════════╪═════════════════════╪════════════╪═══════════════╪═════════════════╡
│       85 │ 2025-04-02 02:23:03 │        109 │         54.81 │           54.81 │
│       85 │ 2025-04-02 02:23:03 │        177 │        125.14 │          125.14 │
│       85 │ 2025-04-02 02:23:03 │        300 │         24.89 │           24.89 │
│       85 │ 2025-04-02 02:23:03 │        310 │        285.11 │          285.11 │
╰──────────┴─────────────────────┴────────────┴───────────────┴─────────────────╯
```

They match — the pipeline that recorded these orders was honest. The join condition mixes an equality (`product_id`) with a range (`ordered_at` inside the validity window), and because intervals per product don't overlap, each line matches exactly one price row: no fan-out. This "join each fact to the dimension row valid *at that time*" pattern is the **point-in-time join**, a staple of warehouse work — Module 11 develops it (and what to do when intervals are missing or overlap).

## Pitfalls

These four pitfalls produce *plausible-looking wrong numbers*, which is far worse than an error message. Every senior data engineer has been burned by at least one.

### Pitfall 1: join fan-out — the most expensive bug in analytics

Joining a one-row-per-order table to a many-rows-per-order table multiplies the order rows. Any aggregate over the *order-level* columns then counts each order multiple times. Watch it happen — January 2026 order count and shipping charged:

```sql
-- BAD: joining order_items multiplies each order by its item count,
-- inflating both aggregates
SELECT
    COUNT(o.order_id)              AS orders,
    ROUND(SUM(o.shipping_cost), 2) AS shipping_collected
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-01-01' AND o.ordered_at < '2026-02-01';
```

```text
╭────────┬────────────────────╮
│ orders │ shipping_collected │
╞════════╪════════════════════╡
│    482 │             3002.7 │
╰────────┴────────────────────╯
```

The truth, straight from `orders`:

```sql
SELECT
    COUNT(*)                     AS orders,
    ROUND(SUM(shipping_cost), 2) AS shipping_collected
FROM orders
WHERE status <> 'cancelled'
  AND ordered_at >= '2026-01-01' AND ordered_at < '2026-02-01';
```

```text
╭────────┬────────────────────╮
│ orders │ shipping_collected │
╞════════╪════════════════════╡
│    201 │             1177.2 │
╰────────┴────────────────────╯
```

201 orders, not 482 — the bad query overstated shipping revenue by 2.5x, and nothing about its output looked wrong. The join itself wasn't the mistake; aggregating order-grain values over line-grain rows was. Two fixes, by situation.

**Fix A — `COUNT(DISTINCT ...)`** when you need the join (here, for item revenue) but must count orders:

```sql
SELECT
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS gross_item_revenue
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-01-01' AND o.ordered_at < '2026-02-01';
```

```text
╭────────┬────────────────────╮
│ orders │ gross_item_revenue │
╞════════╪════════════════════╡
│    201 │          128438.46 │
╰────────┴────────────────────╯
```

The `SUM` is safe (item revenue is line-grain); the count is de-duplicated. But `DISTINCT` can't rescue a `SUM` of a repeated value — for that you need Fix B. Total January revenue *including shipping* (order total = item revenue + shipping, per the canonical definitions):

```sql
-- BAD: shipping_cost is repeated on every item row, so it's added once per item
SELECT
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)
              + o.shipping_cost), 2) AS jan_revenue_with_shipping
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-01-01' AND o.ordered_at < '2026-02-01';
```

```text
╭───────────────────────────╮
│ jan_revenue_with_shipping │
╞═══════════════════════════╡
│                 131441.16 │
╰───────────────────────────╯
```

**Fix B — pre-aggregate to the right grain first.** Collapse items to one row per order *inside a derived table*, then add shipping once:

```sql
SELECT
    ROUND(SUM(per_order.items_revenue + per_order.shipping_cost), 2) AS jan_revenue_with_shipping
FROM (
    SELECT
        o.order_id,
        o.shipping_cost,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS items_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
      AND o.ordered_at >= '2026-01-01' AND o.ordered_at < '2026-02-01'
    GROUP BY o.order_id, o.shipping_cost
) AS per_order;
```

```text
╭───────────────────────────╮
│ jan_revenue_with_shipping │
╞═══════════════════════════╡
│                 129615.66 │
╰───────────────────────────╯
```

The bad version overcharged by 1,825.50 — shipping counted once per item instead of once per order. Fan-out gets *multiplicative* when you join two child tables at once. Order 85 has 4 items and 2 payment attempts:

```sql
-- BAD: as a basis for any aggregation — 4 items x 2 payments = 8 rows
SELECT
    o.order_id,
    oi.product_id,
    pay.payment_id,
    pay.status AS payment_status
FROM orders AS o
JOIN order_items AS oi
    ON oi.order_id = o.order_id
JOIN payments AS pay
    ON pay.order_id = o.order_id
WHERE o.order_id = 85;
```

```text
╭──────────┬────────────┬────────────┬────────────────╮
│ order_id │ product_id │ payment_id │ payment_status │
╞══════════╪════════════╪════════════╪════════════════╡
│       85 │        109 │         86 │ failed         │
│       85 │        177 │         86 │ failed         │
│       85 │        300 │         86 │ failed         │
│       85 │        310 │         86 │ failed         │
│       85 │        109 │         87 │ captured       │
│       85 │        177 │         87 │ captured       │
│       85 │        300 │         87 │ captured       │
│       85 │        310 │         87 │ captured       │
╰──────────┴────────────┴────────────┴────────────────╯
```

Every item now appears twice and every payment four times; summing anything from either table is wrong. The rule: **never join two independent child tables of the same parent directly** — aggregate each child to the parent's grain first, then join the aggregates (Module 5's CTE pipelines make this clean).

### Pitfall 2: the accidental CROSS JOIN

SQLite lets you write `JOIN` with no `ON` clause at all — and silently gives you the Cartesian product:

```sql
-- BAD: no ON clause — SQLite silently produces the Cartesian product
SELECT COUNT(*) AS row_count
FROM orders AS o
JOIN customers AS c;
```

```text
╭───────────╮
│ row_count │
╞═══════════╡
│   4800000 │
╰───────────╯
```

6,000 × 800 = 4.8 million rows. A subtler variant passes review more easily — an `ON` clause that's syntactically fine but compares a column *to itself*:

```sql
-- BAD: both sides of the ON refer to the same table — the condition is
-- always true, so this is still a cross join
SELECT COUNT(*) AS row_count
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = o.customer_id;
```

```text
╭───────────╮
│ row_count │
╞═══════════╡
│   4800000 │
╰───────────╯
```

The fix — an `ON` that references **both** sides:

```sql
SELECT COUNT(*) AS row_count
FROM orders AS o
JOIN customers AS c
    ON c.customer_id = o.customer_id;
```

```text
╭───────────╮
│ row_count │
╞═══════════╡
│      6000 │
╰───────────╯
```

Defenses: sanity-check row counts after writing a join (a join "up" a foreign key should never grow the row count); write the `ON` immediately after each `JOIN` before moving on; and when you *mean* a Cartesian product, write `CROSS JOIN` explicitly so readers know it's intentional.

> **PostgreSQL note:** PostgreSQL refuses `JOIN` without an `ON`/`USING` clause — it's a syntax error there. The self-comparing `ON` variant, however, bites in every database.

### Pitfall 3: filtering a LEFT JOIN's right table in WHERE

Goal: **every opted-in customer with their 2026 non-cancelled order count — including the zeros** (marketing wants to know who to re-engage). The natural-looking query:

```sql
-- BAD: the WHERE conditions on o.* silently turn the LEFT JOIN into an INNER JOIN
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer,
    COUNT(o.order_id) AS orders_2026
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
WHERE c.marketing_opt_in = 1
  AND o.status <> 'cancelled'
  AND o.ordered_at >= '2026-01-01'
GROUP BY c.customer_id, customer
ORDER BY c.customer_id
LIMIT 5;
```

```text
╭─────────────┬─────────────────┬─────────────╮
│ customer_id │    customer     │ orders_2026 │
╞═════════════╪═════════════════╪═════════════╡
│           3 │ Ulf Hansen      │           2 │
│          10 │ Nora Karlsson   │           1 │
│          12 │ Wilma Magnusson │          24 │
│          14 │ Anders Vik      │           3 │
│          24 │ Per Moller      │           3 │
╰─────────────┴─────────────────┴─────────────╯
```

... 208 rows total — but there are **317** opted-in customers. The 109 with zero 2026 orders — the exact people marketing asked about — are gone. Why: for an unmatched customer, the LEFT JOIN fills `o.status` and `o.ordered_at` with NULL; `NULL <> 'cancelled'` evaluates to NULL, and `WHERE` drops non-TRUE rows (Module 2's three-valued logic). The preserved rows are filtered right back out, which is exactly what an INNER JOIN would have produced.

The fix: conditions on the **right** table belong in the `ON` clause, so they restrict *what counts as a match* rather than which result rows survive:

```sql
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer,
    COUNT(o.order_id) AS orders_2026
FROM customers AS c
LEFT JOIN orders AS o
    ON o.customer_id = c.customer_id
   AND o.status <> 'cancelled'
   AND o.ordered_at >= '2026-01-01'
WHERE c.marketing_opt_in = 1
GROUP BY c.customer_id, customer
ORDER BY c.customer_id
LIMIT 5;
```

```text
╭─────────────┬─────────────────┬─────────────╮
│ customer_id │    customer     │ orders_2026 │
╞═════════════╪═════════════════╪═════════════╡
│           3 │ Ulf Hansen      │           2 │
│           8 │ Priya Tanaka    │           0 │
│          10 │ Nora Karlsson   │           1 │
│          12 │ Wilma Magnusson │          24 │
│          14 │ Anders Vik      │           3 │
╰─────────────┴─────────────────┴─────────────╯
```

... 317 rows total. Priya Tanaka reappears with her zero. Note `COUNT(o.order_id)`, not `COUNT(*)`: it counts only non-NULL values (Module 3), so unmatched customers correctly show 0 instead of 1. The rule of thumb:

- Filter on the **left** table → `WHERE` (you're choosing which rows to report on).
- Filter on the **right** table of a LEFT JOIN → `ON` (you're defining what a match is).
- The one deliberate exception: the anti-join's `WHERE right.pk IS NULL`, where filtering on the right table's NULL-ness *is* the point.

For an INNER JOIN the two placements give identical results — which is precisely why habits formed on inner joins betray you on outer ones.

### Pitfall 4: NOT IN with NULLs

Merchandising asks: **which products got no clickstream events at all in June 2026?** (Nobody even *looked* at them — candidates for delisting.) The `NOT IN` attempt:

```sql
-- BAD: the subquery returns NULLs (search and begin_checkout events have
-- NULL product_id), so NOT IN returns zero rows — for any product
SELECT COUNT(*) AS untouched_products
FROM products
WHERE product_id NOT IN (
    SELECT product_id
    FROM events
    WHERE occurred_at >= '2026-06-01' AND occurred_at < '2026-07-01'
);
```

```text
╭────────────────────╮
│ untouched_products │
╞════════════════════╡
│                  0 │
╰────────────────────╯
```

Zero products — believable, and wrong. The subquery's column contains NULLs:

```sql
SELECT COUNT(*) AS null_product_ids
FROM events
WHERE occurred_at >= '2026-06-01' AND occurred_at < '2026-07-01'
  AND product_id IS NULL;
```

```text
╭──────────────────╮
│ null_product_ids │
╞══════════════════╡
│               90 │
╰──────────────────╯
```

Recall Module 2: `x NOT IN (a, b, NULL)` means `x <> a AND x <> b AND x <> NULL`. That last comparison is NULL, never TRUE — so the whole conjunction can be FALSE (when x matches something) or NULL (when it doesn't), but **never TRUE**. One NULL in the list poisons the entire `NOT IN`, and it fails *silently*, returning an empty set. (Plain `IN` degrades more gently: it can still find matches, it just can't prove absence.)

The fix — `NOT EXISTS`, which has no such failure mode because it counts matching *rows* instead of comparing *values*:

```sql
SELECT COUNT(*) AS untouched_products
FROM products AS p
WHERE NOT EXISTS (
    SELECT 1
    FROM events AS e
    WHERE e.product_id = p.product_id
      AND e.occurred_at >= '2026-06-01' AND e.occurred_at < '2026-07-01'
);
```

```text
╭────────────────────╮
│ untouched_products │
╞════════════════════╡
│                 17 │
╰────────────────────╯
```

17 real answers. If you must use `NOT IN`, exclude NULLs explicitly in the subquery:

```sql
SELECT COUNT(*) AS untouched_products
FROM products
WHERE product_id NOT IN (
    SELECT product_id
    FROM events
    WHERE occurred_at >= '2026-06-01' AND occurred_at < '2026-07-01'
      AND product_id IS NOT NULL
);
```

```text
╭────────────────────╮
│ untouched_products │
╞════════════════════╡
│                 17 │
╰────────────────────╯
```

But the professional default is simpler: **for anti-joins, always reach for `NOT EXISTS` first.** It's immune to NULLs whether or not you remembered the column was nullable — and columns have a way of becoming nullable after you wrote the query.

## Exercises

Answer each as a runnable query against `shop.db`. Use the canonical metric definitions from `DATASET.md` wherever revenue or activity is involved. No answers here — solutions live in `solutions/04-joins.md`.

**Warm-up**

1. Fulfillment wants a spot-check list: the 10 most recently placed orders with status `delivered`, showing order id, order timestamp, the customer's full name, and their country.
2. Procurement is reviewing Norwegian partners. List every product supplied by suppliers based in Norway: product name, SKU, and supplier name, sorted by supplier then product.
3. Produce the catalog navigation map: all 19 child categories with their parent category's name, sorted by parent then child. (One table, two roles.)

**Core**

4. Which products have never received a single review? Report how many there are, then list the 5 most expensive of them (name, unit price, active flag) — expensive unreviewed products are a conversion liability.
5. Marketing wants a re-engagement list: how many customers who opted in to marketing placed **no** non-cancelled order in 2026? (They may well have ordered in earlier years.) Return the count, then 5 example customers with their emails.
6. Finance needs 2025 gross revenue per category (the child category on the product), top 10 by revenue, with the number of distinct orders that contributed to each. Make sure neither number is inflated by the join.
7. Logistics review: for each carrier, report total shipments, how many are delivered, how many are still in transit, the average days from `shipped_at` to `delivered_at` (delivered shipments only), and how many distinct customers the carrier has served.
8. How many customers were **active in 2026** (canonical definition) *and* have written at least one review — ever? One query, no joins that multiply rows.

**Challenge**

9. Executive dashboard: 2025 gross revenue per **top-level** category (Camping, Climbing, Hiking, Winter Sports, Water Sports, Apparel), highest first. Products link to child categories, so you'll need the tree.
10. Retention analysis: find pairs of orders placed by the **same customer within 7 days of each other**, where the earlier order was placed in 2026. Report how many such pairs exist, then show the 5 closest-spaced pairs (customer, both order ids, both timestamps, days apart). Careful: in this dataset, order ids are **not** assigned in chronological order.
11. Supplier scorecard: for each supplier, report how many products they supply, how many of those have sold at least once, and how many have never sold. Show only suppliers with at least one never-sold product, worst first. (Hint: `COUNT(DISTINCT ...)` ignores NULLs.)

## Key takeaways

- A join filters the conceptual Cartesian product through the `ON` condition; each surviving pair is one output row. Always know the **grain** of the result.
- `JOIN` = `INNER JOIN`: matched pairs only. `LEFT JOIN`: every left row survives, unmatched ones NULL-padded. `RIGHT` is a mirrored `LEFT` (use `LEFT`); `FULL` keeps both sides (best for comparing independent row sets). `CROSS JOIN` is the raw product — write it explicitly only when you mean it.
- Alias every table; qualify every column; put each `ON` right after its `JOIN`.
- `USING (col)` = equality shorthand for same-named columns; avoid `NATURAL JOIN`.
- Joining "up" a foreign key (child → parent) never multiplies rows; joining "down" (parent → children) multiplies by child count — that's **fan-out**. `COUNT(DISTINCT pk)` fixes inflated counts; pre-aggregating each child table to the parent grain fixes inflated sums. Never join two child tables of the same parent directly.
- Anti-join spellings: `NOT EXISTS` (default), `LEFT JOIN ... WHERE right.pk IS NULL` (test a NOT NULL column), `NOT IN` (avoid: one NULL in the subquery silently returns zero rows).
- Semi-joins (`EXISTS` / `IN`) filter without multiplying rows — prefer them over `JOIN` + `DISTINCT` when you only need "has at least one".
- LEFT JOIN + `WHERE` on the right table = accidental INNER JOIN. Right-table predicates go in `ON`; left-table predicates go in `WHERE`; the `IS NULL` anti-join test is the exception.
- `ON` takes any boolean expression — equality plus range conditions gives point-in-time joins (Module 11).
- Self-joins need two aliases; deduplicate pairs with a strict `>` on a key, and order pairs by timestamp when sequence matters.
