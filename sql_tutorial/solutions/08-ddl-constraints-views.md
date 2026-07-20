# Module 8 Solutions — DDL, Constraints & Views

All solutions run against the module's scratch copy, `/tmp/sqlab/scratch.db`, **after** the module's blocks have been run in order (so `v_order_revenue`, `support_tickets`, and `suppliers.preferred` exist). Blocks that rely on foreign-key enforcement start with `PRAGMA foreign_keys = ON;` because each new connection forgets it. Timestamps produced by `DEFAULT CURRENT_TIMESTAMP` will differ on your machine.

## Warm-up

### Exercise 1 — showrooms

```sql
CREATE TABLE showrooms (
    showroom_id INTEGER PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    country     TEXT NOT NULL,
    city        TEXT NOT NULL,
    opened_on   TEXT,
    is_flagship INTEGER NOT NULL DEFAULT 0 CHECK (is_flagship IN (0, 1))
) STRICT;

INSERT INTO showrooms (name, country, city, is_flagship)
VALUES ('Nordkart Oslo Flagship', 'Norway', 'Oslo', 1);

SELECT * FROM showrooms;
```

```text
╭─────────────┬────────────────────────┬─────────┬──────┬───────────┬─────────────╮
│ showroom_id │          name          │ country │ city │ opened_on │ is_flagship │
╞═════════════╪════════════════════════╪═════════╪══════╪═══════════╪═════════════╡
│           1 │ Nordkart Oslo Flagship │ Norway  │ Oslo │           │           1 │
╰─────────────┴────────────────────────┴─────────┴──────┴───────────┴─────────────╯
```

`showroom_id` auto-assigned itself (INTEGER PRIMARY KEY = rowid alias), `opened_on` defaulted to NULL because it is the one optional column, and STRICT means a future `'yes'` in `is_flagship` will error instead of being stored as text. Common mistake: declaring `is_flagship BOOLEAN` — that's not a legal STRICT type name (`CREATE TABLE` would fail); SQLite booleans are `INTEGER` + a CHECK.

### Exercise 2 — prediction drill

**a) Duplicate email — prediction: fails, `customers.email` is declared `UNIQUE`.**

```sql
-- BAD: duplicate email — customers.email is UNIQUE
PRAGMA foreign_keys = ON;

INSERT INTO customers (first_name, last_name, email, country, city, created_at)
SELECT 'Test', 'Clone', email, country, city, '2026-07-15 12:00:00'
FROM customers
WHERE customer_id = 1;
```

```text
Error near line 4: UNIQUE constraint failed: customers.email
```

**b) Negative price — prediction: fails, `products.unit_price` has `CHECK (unit_price >= 0)`.**

```sql
-- BAD: negative price — products.unit_price has CHECK (unit_price >= 0)
PRAGMA foreign_keys = ON;

INSERT INTO products (sku, name, category_id, supplier_id,
                      unit_price, unit_cost, is_active, introduced_at)
VALUES ('NK-TEST-NEG', 'Anti-Lantern', 7, 1, -1, 0, 1, '2026-07-15');
```

```text
Error near line 4: CHECK constraint failed: unit_price >= 0
```

**c) Omitted `shipping_cost` — prediction: succeeds.** The column is `NOT NULL` but carries `DEFAULT 0`, so omitting it means "free shipping", not NULL:

```sql
PRAGMA foreign_keys = ON;

INSERT INTO orders (customer_id, address_id, status, ordered_at)
VALUES (1, 1, 'pending', '2026-07-15 12:00:00');

SELECT order_id, status, shipping_cost
FROM orders
ORDER BY order_id DESC
LIMIT 1;
```

```text
╭──────────┬─────────┬───────────────╮
│ order_id │ status  │ shipping_cost │
╞══════════╪═════════╪═══════════════╡
│     9002 │ pending │           0.0 │
╰──────────┴─────────┴───────────────╯
```

(It landed at order_id 9002 — `max(rowid) + 1` above the module's demo order 9001, not above 6000. Auto-assigned ids follow the *maximum*, not the count.) Cleanup:

```sql
DELETE FROM orders WHERE order_id = 9002;

SELECT COUNT(*) AS test_orders_left FROM orders WHERE order_id = 9002;
```

```text
╭──────────────────╮
│ test_orders_left │
╞══════════════════╡
│                0 │
╰──────────────────╯
```

### Exercise 3 — product_questions

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE product_questions (
    question_id INTEGER PRIMARY KEY,
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    question    TEXT    NOT NULL,
    asked_at    TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_public   INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1))
);

INSERT INTO product_questions (product_id, customer_id, question)
VALUES (12, 42, 'Do these bindings fit 110mm-waist skis?');

SELECT * FROM product_questions;
```

```text
╭─────────────┬────────────┬─────────────┬─────────────────────────────────────────┬─────────────────────┬───────────╮
│ question_id │ product_id │ customer_id │                question                 │      asked_at       │ is_public │
╞═════════════╪════════════╪═════════════╪═════════════════════════════════════════╪═════════════════════╪═══════════╡
│           1 │         12 │          42 │ Do these bindings fit 110mm-waist skis? │ 2026-07-15 23:50:36 │         1 │
╰─────────────┴────────────┴─────────────┴─────────────────────────────────────────┴─────────────────────┴───────────╯
```

Three columns filled themselves in: the PK (rowid alias), `asked_at` (UTC arrival stamp — yours will differ), and `is_public = 1`. This PK + FKs + workflow-default skeleton is the same shape as the module's `support_tickets` — it is *the* standard operational-table template.

## Core

### Exercise 4 — gift cards

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE gift_cards (
    gift_card_id  INTEGER PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,
    initial_value REAL NOT NULL CHECK (initial_value > 0),
    balance       REAL NOT NULL,
    purchased_by  INTEGER REFERENCES customers(customer_id) ON DELETE SET NULL,
    issued_at     TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'redeemed', 'expired')),
    CHECK (balance BETWEEN 0 AND initial_value)
);

CREATE TABLE gift_card_redemptions (
    redemption_id INTEGER PRIMARY KEY,
    gift_card_id  INTEGER NOT NULL
                  REFERENCES gift_cards(gift_card_id) ON DELETE CASCADE,
    order_id      INTEGER NOT NULL
                  REFERENCES orders(order_id) ON DELETE RESTRICT,
    amount        REAL NOT NULL CHECK (amount > 0),
    redeemed_at   TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

```text
(no output — two tables created)
```

The proof that the cross-column CHECK works:

```sql
-- BAD: a card cannot hold more balance than it was issued with
PRAGMA foreign_keys = ON;

INSERT INTO gift_cards (code, initial_value, balance, purchased_by)
VALUES ('NK-GC-0001', 500, 600, 42);
```

```text
Error near line 4: CHECK constraint failed: balance BETWEEN 0 AND initial_value
```

Design notes: `balance BETWEEN 0 AND initial_value` must be a **table constraint** (it compares two columns); `purchased_by` is nullable *because* `ON DELETE SET NULL` needs somewhere to put the NULL — a `NOT NULL` column with SET NULL would make every parent delete fail. Redemptions cascade with their card (detail rows), but an order with redemptions is protected by RESTRICT (money is involved).

### Exercise 5 — wishlists

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE wishlists (
    wishlist_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL
                REFERENCES customers(customer_id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (customer_id, name)
);

CREATE TABLE wishlist_items (
    wishlist_id INTEGER NOT NULL
                REFERENCES wishlists(wishlist_id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    added_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (wishlist_id, product_id)
);

INSERT INTO wishlists (customer_id, name) VALUES (42, 'Autumn hikes');
INSERT INTO wishlist_items (wishlist_id, product_id) VALUES (1, 12), (1, 25);

SELECT w.name, wi.product_id, p.name AS product
FROM wishlists w
JOIN wishlist_items wi USING (wishlist_id)
JOIN products p USING (product_id);
```

```text
╭──────────────┬────────────┬──────────────────────╮
│     name     │ product_id │       product        │
╞══════════════╪════════════╪══════════════════════╡
│ Autumn hikes │         12 │ Fjell Ski Bindings   │
│ Autumn hikes │         25 │ Flake Snowshoes 30in │
╰──────────────┴────────────┴──────────────────────╯
```

```sql
PRAGMA foreign_keys = ON;

DELETE FROM wishlists WHERE customer_id = 42 AND name = 'Autumn hikes';

SELECT
    (SELECT COUNT(*) FROM wishlists)      AS wishlists_left,
    (SELECT COUNT(*) FROM wishlist_items) AS items_left;
```

```text
╭────────────────┬────────────╮
│ wishlists_left │ items_left │
╞════════════════╪════════════╡
│              0 │          0 │
╰────────────────┴────────────╯
```

One DELETE, both tables emptied — the CASCADE did the second half. The two subtleties graders look for: "a customer cannot have two wishlists with the same name" is the composite `UNIQUE (customer_id, name)` — a plain `name UNIQUE` would wrongly forbid two *different* customers from both having "Autumn hikes"; and "one row per product per wishlist" is the composite PK, the same M:N pattern as `order_items`.

### Exercise 6 — supplier codes via the recreate pattern

`ALTER TABLE ADD COLUMN` cannot add a UNIQUE column, so: recreate. Remember that the module's §8 added `preferred` — the new table must carry it, or you'd silently drop a column (always check `SELECT sql FROM sqlite_schema WHERE name='suppliers';` before writing the new DDL).

```sql
PRAGMA foreign_keys = OFF;

BEGIN;

CREATE TABLE suppliers_new (
    supplier_id   INTEGER PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE,
    country       TEXT NOT NULL,
    contact_email TEXT,
    preferred     INTEGER NOT NULL DEFAULT 0 CHECK (preferred IN (0, 1)),
    supplier_code TEXT NOT NULL UNIQUE
);

INSERT INTO suppliers_new
SELECT supplier_id, name, country, contact_email, preferred,
       printf('SUP-%03d', supplier_id)
FROM suppliers;

DROP TABLE suppliers;

ALTER TABLE suppliers_new RENAME TO suppliers;

COMMIT;

PRAGMA foreign_keys = ON;
PRAGMA foreign_key_check;

SELECT supplier_id, name, supplier_code, preferred FROM suppliers LIMIT 3;
```

```text
╭─────────────┬─────────────────────┬───────────────┬───────────╮
│ supplier_id │        name         │ supplier_code │ preferred │
╞═════════════╪═════════════════════╪═══════════════╪═══════════╡
│           1 │ Fjellutstyr AS      │ SUP-001       │         0 │
│           2 │ Nordic Trail Supply │ SUP-002       │         0 │
│           3 │ Alpin Werke GmbH    │ SUP-003       │         0 │
╰─────────────┴─────────────────────┴───────────────┴───────────╯
```

`foreign_key_check` printed nothing: `products.supplier_id` still resolves, because the FK references the table *name*, and the rename put the name back. The backfill happens *inside* the copy — one pass, no separate UPDATE needed. Common wrong approach: `ALTER TABLE suppliers ADD COLUMN supplier_code TEXT NOT NULL UNIQUE;` — fails immediately (`Cannot add a UNIQUE column`), which is the whole reason this is a recreate job.

### Exercise 7 — v_monthly_revenue

The canonical definitions say gross revenue and AOV both exclude **cancelled** orders (returned orders stay in gross), so the view filters `status <> 'cancelled'`:

```sql
CREATE VIEW v_monthly_revenue AS
SELECT
    strftime('%Y-%m', ordered_at) AS month,
    COUNT(*)                      AS orders,
    ROUND(SUM(item_revenue), 2)   AS gross_revenue,
    ROUND(AVG(order_total), 2)    AS aov
FROM v_order_revenue
WHERE status <> 'cancelled'
GROUP BY month;

SELECT *
FROM v_monthly_revenue
WHERE month >= '2026-01'
ORDER BY month DESC;
```

```text
╭─────────┬────────┬───────────────┬────────╮
│  month  │ orders │ gross_revenue │  aov   │
╞═════════╪════════╪═══════════════╪════════╡
│ 2026-07 │    364 │     181415.81 │ 503.97 │
│ 2026-06 │    570 │      288614.9 │ 512.34 │
│ 2026-05 │    436 │      234748.8 │ 544.25 │
│ 2026-04 │    346 │     194769.61 │ 568.46 │
│ 2026-03 │    288 │      170011.1 │ 595.79 │
│ 2026-02 │    217 │     118340.14 │ 550.58 │
│ 2026-01 │    201 │     128438.43 │ 644.85 │
╰─────────┴────────┴───────────────┴────────╯
```

A view stacked on a view: `v_order_revenue` supplies correct per-order arithmetic; this one only aggregates — that layering is the CTE-pipeline idea (Module 5) made permanent. Two things worth noticing against the module's snapshot table: 2026-07 shows **364** orders, not 363 — the view picked up demo order 9001 that was inserted *after* the snapshot was frozen; and 2026-06 reads 288614.9 vs the snapshot's 288614.97 — `v_order_revenue` rounds each order to cents before this view sums, so totals can drift by cents from a raw single-pass sum. Fine for reporting; know that it happens.

### Exercise 8 — products_v2 with a generated margin

```sql
CREATE TABLE products_v2 (
    product_id    INTEGER PRIMARY KEY,
    sku           TEXT NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    category_id   INTEGER NOT NULL REFERENCES categories(category_id),
    supplier_id   INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    unit_price    REAL NOT NULL CHECK (unit_price >= 0),
    unit_cost     REAL NOT NULL CHECK (unit_cost >= 0),
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    introduced_at TEXT NOT NULL,
    margin_pct    REAL GENERATED ALWAYS AS
                  (ROUND((unit_price - unit_cost) / unit_price * 100, 1)) STORED
);

INSERT INTO products_v2 (product_id, sku, name, category_id, supplier_id,
                         unit_price, unit_cost, is_active, introduced_at)
SELECT product_id, sku, name, category_id, supplier_id,
       unit_price, unit_cost, is_active, introduced_at
FROM products;

SELECT name, unit_price, unit_cost, margin_pct
FROM products_v2
WHERE is_active = 1
ORDER BY margin_pct DESC
LIMIT 5;
```

```text
╭─────────────────────────┬────────────┬───────────┬────────────╮
│          name           │ unit_price │ unit_cost │ margin_pct │
╞═════════════════════════╪════════════╪═══════════╪════════════╡
│ Core Rope 70m           │     147.33 │     61.89 │       58.0 │
│ Rescue Avalanche Beacon │     834.53 │    351.53 │       57.9 │
│ Flex Ski Poles          │     101.75 │     43.18 │       57.6 │
│ Fjell Quilt             │     205.85 │     87.47 │       57.5 │
│ Vandra Backpack 35L     │     273.31 │    116.49 │       57.4 │
╰─────────────────────────┴────────────┴───────────┴────────────╯
```

The INSERT names only the real columns — listing `margin_pct` would error (`cannot INSERT into generated column`), which is why an explicit column list, not `SELECT *` into the table, is mandatory here. From now on, `margin_pct` can never disagree with the prices it is derived from. (One lurking edge: a product with `unit_price = 0` would make the expression divide by zero — SQLite yields NULL rather than erroring, so free products would simply have NULL margin.)

## Challenge

### Exercise 9 — FK-action predictions

Seed (a subquery fetches the card's id rather than hard-coding it — auto-assigned ids are not guessable, as exercise 2c showed):

```sql
PRAGMA foreign_keys = ON;

INSERT INTO gift_cards (code, initial_value, balance, purchased_by)
VALUES ('NK-GC-0002', 500, 350, 500);

INSERT INTO gift_card_redemptions (gift_card_id, order_id, amount)
VALUES ((SELECT gift_card_id FROM gift_cards WHERE code = 'NK-GC-0002'), 3000, 150);

SELECT r.redemption_id, gc.gift_card_id, gc.code, gc.purchased_by, r.order_id, r.amount
FROM gift_card_redemptions r
JOIN gift_cards gc USING (gift_card_id);
```

```text
╭───────────────┬──────────────┬────────────┬──────────────┬──────────┬────────╮
│ redemption_id │ gift_card_id │    code    │ purchased_by │ order_id │ amount │
╞═══════════════╪══════════════╪════════════╪══════════════╪══════════╪════════╡
│             1 │            1 │ NK-GC-0002 │          500 │     3000 │  150.0 │
╰───────────────┴──────────────┴────────────┴──────────────┴──────────┴────────╯
```

**a) Prediction: blocked.**

```sql
-- BAD: order 3000 has a gift-card redemption (RESTRICT) — and order_items,
-- payments and shipments rows besides (NO ACTION): the delete is blocked
PRAGMA foreign_keys = ON;
DELETE FROM orders WHERE order_id = 3000;
```

```text
Error near line 4: FOREIGN KEY constraint failed
```

**b) Prediction: the card disappears and takes its redemption with it (CASCADE).**

```sql
PRAGMA foreign_keys = ON;

DELETE FROM gift_cards WHERE code = 'NK-GC-0002';

SELECT
    (SELECT COUNT(*) FROM gift_cards)            AS cards_left,
    (SELECT COUNT(*) FROM gift_card_redemptions) AS redemptions_left;
```

```text
╭────────────┬──────────────────╮
│ cards_left │ redemptions_left │
╞════════════╪══════════════════╡
│          0 │                0 │
╰────────────┴──────────────────╯
```

Why they differ: `gift_card_redemptions.order_id` declares `ON DELETE RESTRICT` — an order with money movements must never be deletable — while `gift_card_redemptions.gift_card_id` declares `ON DELETE CASCADE`, so redemption rows are treated as details of the card. Honesty note on (a): even without our RESTRICT, order 3000 would still be protected, because `order_items`, `payments`, and `shipments` all reference `orders` with the default `NO ACTION` — in this schema, deleting any real order is effectively forbidden several times over, which is exactly right for financial data. And had we deleted customer 500 (blocked in practice by their `addresses`/`orders` rows), `purchased_by` would have become NULL — SET NULL severs the link but keeps the record.

### Exercise 10 — adding a status to the whitelist

The naive dance fails halfway: after `DROP TABLE orders`, the step `ALTER TABLE orders_new RENAME TO orders` errors with `error in view v_order_revenue: no such table: main.orders`, because RENAME re-parses every view to fix up references. That is the 12-step procedure's "drop and recreate dependent views" step earning its keep. Both `v_order_revenue` and `v_monthly_revenue` (which sits on top of it) must be dropped and recreated inside the migration:

```sql
PRAGMA foreign_keys = OFF;

BEGIN;

-- Step 0 the docs warn about: views that reference `orders` must be dropped
-- first (ALTER ... RENAME re-parses every view and errors out otherwise),
-- and recreated afterwards.
DROP VIEW v_monthly_revenue;
DROP VIEW v_order_revenue;

CREATE TABLE orders_new (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
    address_id    INTEGER NOT NULL REFERENCES addresses(address_id),
    status        TEXT NOT NULL CHECK (status IN
                      ('pending', 'paid', 'shipped', 'delivered',
                       'refund_pending', 'cancelled', 'returned')),
    shipping_cost REAL NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    ordered_at    TEXT NOT NULL
);

INSERT INTO orders_new
SELECT order_id, customer_id, address_id, status, shipping_cost, ordered_at
FROM orders;

DROP TABLE orders;

ALTER TABLE orders_new RENAME TO orders;

CREATE VIEW v_order_revenue AS
SELECT
    o.order_id,
    o.customer_id,
    o.status,
    o.ordered_at,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
        AS item_revenue,
    o.shipping_cost,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0))
          + o.shipping_cost, 2)
        AS order_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

CREATE VIEW v_monthly_revenue AS
SELECT
    strftime('%Y-%m', ordered_at) AS month,
    COUNT(*)                      AS orders,
    ROUND(SUM(item_revenue), 2)   AS gross_revenue,
    ROUND(AVG(order_total), 2)    AS aov
FROM v_order_revenue
WHERE status <> 'cancelled'
GROUP BY month;

COMMIT;

PRAGMA foreign_keys = ON;
PRAGMA foreign_key_check;

SELECT COUNT(*) AS orders_migrated FROM orders;
```

```text
╭─────────────────╮
│ orders_migrated │
╞═════════════════╡
│            6001 │
╰─────────────────╯
```

All 6,001 rows (6,000 original + the module's demo order 9001) survived, and `foreign_key_check` was silent even though four child tables point at `orders` — the swap happened with enforcement off and restored the name before anything could notice. The new status is live:

```sql
PRAGMA foreign_keys = ON;

UPDATE orders SET status = 'refund_pending' WHERE order_id = 1;

SELECT order_id, status FROM orders WHERE order_id = 1;
```

```text
╭──────────┬────────────────╮
│ order_id │     status     │
╞══════════╪════════════════╡
│        1 │ refund_pending │
╰──────────┴────────────────╯
```

Common wrong approaches: trying `ALTER TABLE orders ALTER COLUMN` / `ADD CONSTRAINT` (no such syntax in SQLite), or doing the dance without the transaction — if any step fails halfway (as the view error demonstrates!), a transaction leaves the database exactly as it was; without one you're left with no `orders` table and a heart rate to match.

### Exercise 11 — v_customer_health

```sql
CREATE VIEW v_customer_health AS
SELECT
    customer_id,
    SUM(CASE WHEN status <> 'cancelled' THEN 1 ELSE 0 END)   AS orders,
    ROUND(SUM(CASE WHEN status <> 'cancelled' THEN order_total ELSE 0 END), 2)
                                                             AS lifetime_revenue,
    MAX(ordered_at)                                          AS last_order_at
FROM v_order_revenue
GROUP BY customer_id;

SELECT *
FROM v_customer_health
ORDER BY lifetime_revenue DESC
LIMIT 5;
```

```text
╭─────────────┬────────┬──────────────────┬─────────────────────╮
│ customer_id │ orders │ lifetime_revenue │    last_order_at    │
╞═════════════╪════════╪══════════════════╪═════════════════════╡
│         684 │     46 │          29736.8 │ 2026-07-14 16:21:48 │
│         105 │     50 │         28279.87 │ 2026-06-24 11:56:32 │
│         698 │     42 │          25782.6 │ 2026-07-10 03:25:33 │
│         474 │     43 │         25742.37 │ 2026-06-24 22:40:56 │
│         581 │     43 │         25444.68 │ 2026-06-27 02:59:55 │
╰─────────────┴────────┴──────────────────┴─────────────────────╯
```

The exercise's two different filters live in the same query via conditional aggregation (Module 3): `orders` and `lifetime_revenue` count only non-cancelled orders, while `last_order_at` takes `MAX` over everything — a cancelled order is still customer activity. Grouping over the unfiltered view (rather than putting `WHERE status <> 'cancelled'` on the whole query) is what makes that possible; a whole-query WHERE would silently misreport `last_order_at` for customers whose most recent order was cancelled — and drop customers with *only* cancelled orders entirely.
