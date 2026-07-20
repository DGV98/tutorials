# Module 8 — DDL, Constraints & Views

So far you have only *read* the Nordkart database. Somebody had to build it — decide what a "payment" is, which columns can be NULL, what statuses an order may have, and what happens to order lines when an order is deleted. That somebody is the data engineer, and the language is DDL (Data Definition Language). A schema is the one place where correctness is enforced *for every writer, forever*: a CHECK constraint stops bad data at the door, while a cleanup query only mops up after it. This module teaches you to read the real Nordkart schema critically, and to design tables that make invalid states unrepresentable.

## What you'll learn

- The anatomy of `CREATE TABLE`: column definitions, column constraints vs table constraints
- SQLite's storage classes and **type affinity** — why `'abc'` fits in an INTEGER column, and how **STRICT tables** fix that
- How SQLite typing differs from PostgreSQL's strict types (`VARCHAR`, `NUMERIC`, `TIMESTAMP`, `BOOLEAN`)
- `PRIMARY KEY` and the special `INTEGER PRIMARY KEY` rowid alias; why `AUTOINCREMENT` is usually unnecessary; `WITHOUT ROWID`
- `NOT NULL`, `UNIQUE` (single and composite), `CHECK`, `DEFAULT` (including `DEFAULT CURRENT_TIMESTAMP`)
- `FOREIGN KEY ... REFERENCES` with `ON DELETE` / `ON UPDATE` actions — `CASCADE`, `SET NULL`, `RESTRICT` — and the `PRAGMA foreign_keys = ON` trap
- Generated columns (a line-total column that computes itself)
- What `ALTER TABLE` can and cannot do in SQLite, and the **recreate pattern** for everything else
- `DROP TABLE IF EXISTS`, `TEMP` tables, `CREATE TABLE AS SELECT` (CTAS)
- Views: building `v_order_revenue`, the canonical revenue query, as a reusable saved query — and why a view is *not* a copy of the data

## 0. Work on a copy — never on shop.db

This module creates, alters, and drops tables, and deliberately breaks things. **Do not run it against `shop.db`.** Make a scratch copy first (from the course root):

```bash
mkdir -p /tmp/sqlab
cp shop.db /tmp/sqlab/scratch.db
```

**Every `sql` block from here to the end of the module runs against the copy**, `/tmp/sqlab/scratch.db`. Two ways to run them:

- interactively: `sqlite3 -box /tmp/sqlab/scratch.db`, then paste the block;
- as one-shots: save the block to a file and run `sqlite3 -box /tmp/sqlab/scratch.db < block.sql`.

Prefer one of these two. Passing a block as a command-line argument (`sqlite3 db "..."`) breaks when the block *starts* with a `--` comment — the shell hands it to the CLI, which mistakes `--` for an option flag. Several blocks below start with exactly such a comment.

One more consequence of using one-shots: **each invocation is a brand-new connection**. Settings made with `PRAGMA` (and TEMP tables) live only as long as the connection — which is why you'll see `PRAGMA foreign_keys = ON;` repeated at the top of blocks that need it. This is not paranoia; it is the reality of how SQLite sessions work, and forgetting it is Pitfall 1.

If your copy ever gets into a state you don't like: delete it and re-copy. That is the whole point of a scratch database.

## 1. CREATE TABLE anatomy — reading the real schema

Every table definition is stored as text in the schema catalog, `sqlite_schema` (historically called `sqlite_master`; both names work). Let's pull up the definition of `orders` — the table you've been querying for seven modules:

```sql
SELECT sql FROM sqlite_schema WHERE name = 'orders';
```

```text
╭──────────────────────────────────────────────────────────────────────────────────────────────╮
│                                             sql                                              │
╞══════════════════════════════════════════════════════════════════════════════════════════════╡
│ CREATE TABLE orders (                                                                        │
│     order_id      INTEGER PRIMARY KEY,                                                       │
│     customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),                        │
│     address_id    INTEGER NOT NULL REFERENCES addresses(address_id),                         │
│     status        TEXT NOT NULL CHECK (status IN                                             │
│                       ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned')), │
│     shipping_cost REAL NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),                        │
│     ordered_at    TEXT NOT NULL                                                              │
│ )                                                                                            │
╰──────────────────────────────────────────────────────────────────────────────────────────────╯
```

Read it like a contract. Each line inside the parentheses is a **column definition**: a name, a declared type, and zero or more **column constraints** that qualify just that column:

- `PRIMARY KEY` — `order_id` uniquely identifies each row (more on the INTEGER special case in §4).
- `NOT NULL` — an order without a customer or a timestamp is not an order; the database refuses to store one.
- `REFERENCES customers(customer_id)` — a foreign key: the value must exist in the parent table (§6, with a big caveat).
- `CHECK (status IN (...))` — a whitelist. There are exactly six order statuses in this business; a typo like `'shiped'` is rejected at write time, so every `GROUP BY status` you've ever run could trust the data.
- `DEFAULT 0` — omit `shipping_cost` on insert and it becomes 0 (free shipping), not NULL.

Constraints can also stand on their own line as **table constraints** — required when they span multiple columns. `order_items` shows a composite primary key:

```sql
SELECT sql FROM sqlite_schema WHERE name = 'order_items';
```

```text
╭─────────────────────────────────────────────────────────────────────────────────────╮
│                                         sql                                         │
╞═════════════════════════════════════════════════════════════════════════════════════╡
│ CREATE TABLE order_items (                                                          │
│     order_id     INTEGER NOT NULL REFERENCES orders(order_id),                      │
│     product_id   INTEGER NOT NULL REFERENCES products(product_id),                  │
│     quantity     INTEGER NOT NULL CHECK (quantity > 0),                             │
│     unit_price   REAL NOT NULL CHECK (unit_price >= 0),   -- price at time of order │
│     discount_pct INTEGER NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100), │
│     PRIMARY KEY (order_id, product_id)                                              │
│ )                                                                                   │
╰─────────────────────────────────────────────────────────────────────────────────────╯
```

`PRIMARY KEY (order_id, product_id)` says: one line per product per order. A second row for the same (order, product) pair is impossible — if a customer buys the same product twice in one order, `quantity` goes up instead. That is a *business rule encoded in the schema*, exactly the Module 7 design translated into DDL.

## 2. Storage classes and type affinity — SQLite's flexible typing

Here is the thing that surprises everyone coming from other databases: in ordinary SQLite tables, **the declared type is a suggestion, not a rule**. What SQLite actually stores is one of five **storage classes**: `NULL`, `INTEGER`, `REAL`, `TEXT`, `BLOB` — decided per *value*, not per column.

The declared column type determines the column's **type affinity** — a *preference* the column uses to coerce incoming values when it can do so losslessly. The affinity is derived from the type name by substring rules:

| declared type contains | affinity | examples |
|---|---|---|
| `INT` | INTEGER | `INTEGER`, `BIGINT`, `INT` |
| `CHAR`, `CLOB`, `TEXT` | TEXT | `TEXT`, `VARCHAR(80)` |
| `BLOB` or no type at all | BLOB | `BLOB` |
| `REAL`, `FLOA`, `DOUB` | REAL | `REAL`, `DOUBLE` |
| anything else | NUMERIC | `NUMERIC`, `DECIMAL(10,2)`, `DATE`, `BOOLEAN` |

Watch affinity at work — `typeof()` reveals the storage class each value actually got:

```sql
CREATE TABLE affinity_demo (
    id    INTEGER,
    price REAL,
    label TEXT,
    misc  NUMERIC
);

INSERT INTO affinity_demo VALUES ('42', '19.90', 7, '007');

SELECT id,    typeof(id),
       price, typeof(price),
       label, typeof(label),
       misc,  typeof(misc)
FROM affinity_demo;
```

```text
╭────┬────────────┬───────┬───────────────┬───────┬───────────────┬──────┬──────────────╮
│ id │ typeof(id) │ price │ typeof(price) │ label │ typeof(label) │ misc │ typeof(misc) │
╞════╪════════════╪═══════╪═══════════════╪═══════╪═══════════════╪══════╪══════════════╡
│ 42 │ integer    │  19.9 │ real          │ 7     │ text          │    7 │ integer      │
╰────┴────────────┴───────┴───────────────┴───────┴───────────────┴──────┴──────────────╯
```

Every value we inserted was "wrong" for its column, and every one was quietly converted: the text `'42'` became integer 42, `'19.90'` became real 19.9, the number 7 became the text `'7'`, and `'007'` in the NUMERIC column collapsed to integer 7 (goodbye, leading zeros — a classic way to mangle postal codes and phone numbers).

But coercion only happens when it is lossless. Insert `'abc'` into that INTEGER column and SQLite doesn't error — it stores the text *as text*, inside your INTEGER column. That's Pitfall 2, demonstrated in full at the end of this module. The takeaway for now: in ordinary SQLite tables, column types document intent; they do not enforce it.

This flexibility is why Nordkart stores dates as TEXT (`'2026-07-15 10:00:00'`) — SQLite has no date type at all, and ISO-8601 text sorts and compares correctly. It's also why money is REAL here: convenient, but real systems avoid binary floating point for currency (0.1 has no exact binary representation; sums drift by fractions of a cent). Production schemas store integer cents, or use a database with a decimal type.

> **PostgreSQL note:** PostgreSQL is strictly typed. Columns are really `VARCHAR(n)`, `NUMERIC(12,2)` (exact decimal — the right choice for money), `TIMESTAMP`/`TIMESTAMPTZ`, `DATE`, `BOOLEAN` (true booleans, not 0/1), even arrays (`TEXT[]`) and `JSONB`. Inserting `'abc'` into an `INTEGER` column fails immediately with `invalid input syntax for type integer`. Everything this module says about affinity is SQLite-specific.

## 3. STRICT tables — opting back into type safety

Since SQLite 3.37 you can end a table definition with the keyword `STRICT`, and the column types become enforced rules. This is modern SQLite best practice for any schema you design from scratch. Suppose the warehouse team starts doing physical stock counts:

```sql
CREATE TABLE inventory_counts (
    product_id INTEGER NOT NULL,
    counted_on TEXT    NOT NULL,
    on_hand    INTEGER NOT NULL CHECK (on_hand >= 0),
    PRIMARY KEY (product_id, counted_on)
) STRICT;

INSERT INTO inventory_counts VALUES (1, '2026-07-15', '18');

SELECT product_id, on_hand, typeof(on_hand) FROM inventory_counts;
```

```text
╭────────────┬─────────┬─────────────────╮
│ product_id │ on_hand │ typeof(on_hand) │
╞════════════╪═════════╪═════════════════╡
│          1 │      18 │ integer         │
╰────────────┴─────────┴─────────────────╯
```

Note that `'18'` still went in — STRICT permits *lossless* conversions (a text that is exactly an integer becomes that integer). What it refuses is anything that would have to be stored as the wrong class:

```sql
-- BAD: STRICT refuses what an ordinary table would quietly store
INSERT INTO inventory_counts VALUES (2, '2026-07-15', 'about 20');
```

```text
Error near line 2: cannot store TEXT value in INTEGER column inventory_counts.on_hand
```

That error is the entire value proposition: garbage is rejected at the door, at write time, with a message naming the column — instead of surfacing weeks later as a report that won't add up. Two rules of STRICT to remember: only the type names `INT`, `INTEGER`, `REAL`, `TEXT`, `BLOB`, and `ANY` are allowed (no `VARCHAR(80)` folklore), and every column must have a type. `ANY` is the explicit escape hatch for a genuinely typeless column.

The Nordkart schema itself predates this convention (like most real schemas you will inherit) — its tables are ordinary, which is exactly why `PRAGMA integrity_check` and careful loading matter in this course.

## 4. PRIMARY KEY, the rowid, and AUTOINCREMENT

Every ordinary SQLite table secretly stores its rows in a B-tree keyed by a 64-bit integer called the **rowid** (Module 10 makes heavy use of this fact). Declaring a column as `INTEGER PRIMARY KEY` — exactly that type name — makes the column an *alias for the rowid*. That has a very convenient consequence: leave it out of an INSERT and SQLite assigns `max(rowid) + 1` automatically.

Marketing wants coupon codes:

```sql
CREATE TABLE coupon_codes (
    coupon_id INTEGER PRIMARY KEY,
    code      TEXT NOT NULL UNIQUE
);

INSERT INTO coupon_codes (code) VALUES ('WELCOME10'), ('MIDSUMMER25');

SELECT coupon_id, rowid, code FROM coupon_codes;
```

```text
╭───────────┬───────────┬─────────────╮
│ coupon_id │ coupon_id │    code     │
╞═══════════╪═══════════╪═════════════╡
│         1 │         1 │ WELCOME10   │
│         2 │         2 │ MIDSUMMER25 │
╰───────────┴───────────┴─────────────╯
```

IDs 1 and 2 were assigned without us asking — and look at the column headers: we selected `rowid`, but SQLite reports it as `coupon_id`, because they are literally the same column. Every `*_id INTEGER PRIMARY KEY` in the Nordkart schema works this way.

Now the subtlety. `max + 1` means that if you delete the highest row, its id can be **reused**:

```sql
DELETE FROM coupon_codes WHERE coupon_id = 2;
INSERT INTO coupon_codes (code) VALUES ('FJELL15');

SELECT coupon_id, code FROM coupon_codes;
```

```text
╭───────────┬───────────╮
│ coupon_id │   code    │
╞═══════════╪═══════════╡
│         1 │ WELCOME10 │
│         2 │ FJELL15   │
╰───────────┴───────────╯
```

`FJELL15` took the dead coupon's id 2. If external systems (an email log, a data warehouse, a printed voucher) still remember id 2 as `MIDSUMMER25`, you now have a silent identity collision. `INTEGER PRIMARY KEY AUTOINCREMENT` closes that hole: it tracks the high-water mark in a hidden `sqlite_sequence` table and never reuses an id, at a small write cost. But note when this matters: only if you delete the *maximum* row and ids escape the database. Most tables (like all of Nordkart's) never delete rows at all — which is why the SQLite documentation itself says AUTOINCREMENT is usually unnecessary. Reach for it deliberately, not by habit.

Two related notes for completeness. First, primary keys in SQLite have one historical wart: except for `INTEGER PRIMARY KEY` and STRICT tables, a `PRIMARY KEY` column can technically hold NULL — one more argument for STRICT. Second, a table can be declared `WITHOUT ROWID`, which stores rows in a B-tree keyed directly by the declared primary key instead of a hidden integer — a good fit for tables with a natural composite key like `order_items`, and worth knowing when you meet it in the wild; we won't need it in this course.

> **PostgreSQL note:** there is no rowid. Auto-assigned keys are declared as `id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` (modern SQL standard) or the older `SERIAL`. Both are backed by sequences, and like AUTOINCREMENT they never reuse values — but they may leave gaps (rolled-back inserts consume numbers). Never assume ids are dense.

## 5. NOT NULL, UNIQUE, CHECK, DEFAULT — the everyday constraints

You've now seen all four in the real schema; let's exercise them. `NOT NULL` needs no demo — it refuses NULL, full stop. Note where the schema deliberately *omits* it: `customers.phone`, `reviews.review_text`, `shipments.delivered_at` are nullable because "unknown" and "not yet" are legitimate business states there (Module 2's whole subject).

**CHECK** is your business-rule enforcer. The order status whitelist really works:

```sql
-- BAD: 'shiped' is not on the status whitelist
INSERT INTO orders (customer_id, address_id, status, shipping_cost, ordered_at)
VALUES (1, 1, 'shiped', 0, '2026-07-15 10:00:00');
```

```text
Error near line 2: CHECK constraint failed: status IN
                      ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned')
```

One misspelled status would have silently vanished from every dashboard that filters `status = 'shipped'`. The constraint turns that data bug into an application error at the exact moment someone can still fix it. (CHECK expressions must be things the row itself can answer — comparisons, `IN` lists, arithmetic across the row's own columns. They cannot run subqueries against other tables.)

**UNIQUE** exists in single-column form (`customers.email`, `products.sku`) and composite form. `reviews` declares `UNIQUE (product_id, customer_id)`: one review per customer per product — the *pair* must be unique, though each customer may review many products:

```sql
-- BAD: one review per customer per product — this duplicates an existing one
INSERT INTO reviews (product_id, customer_id, rating, created_at)
SELECT product_id, customer_id, 5, '2026-07-15 10:00:00'
FROM reviews
ORDER BY review_id
LIMIT 1;
```

```text
Error near line 2: UNIQUE constraint failed: reviews.product_id, reviews.customer_id
```

Without this constraint, a double-submitted review form would inflate a product's rating count — and no amount of careful application code protects you as well as the database does, because the database is the *one* chokepoint every writer must pass through.

**DEFAULT** fills in omitted columns. The most useful special form is `DEFAULT CURRENT_TIMESTAMP`, which stamps rows on arrival. Suppose customer service wants a ticket table:

```sql
CREATE TABLE support_tickets (
    ticket_id INTEGER PRIMARY KEY,
    order_id  INTEGER NOT NULL REFERENCES orders(order_id),
    topic     TEXT    NOT NULL,
    status    TEXT    NOT NULL DEFAULT 'open'
              CHECK (status IN ('open', 'pending', 'closed')),
    opened_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO support_tickets (order_id, topic)
VALUES (4001, 'Where is my parcel?');

SELECT * FROM support_tickets;
```

```text
╭───────────┬──────────┬─────────────────────┬────────┬─────────────────────╮
│ ticket_id │ order_id │        topic        │ status │      opened_at      │
╞═══════════╪══════════╪═════════════════════╪════════╪═════════════════════╡
│         1 │     4001 │ Where is my parcel? │ open   │ 2026-07-15 23:43:05 │
╰───────────┴──────────┴─────────────────────┴────────┴─────────────────────╯
```

We supplied two values and got a five-column row: the id auto-assigned, `status` defaulted to `'open'`, and `opened_at` stamped automatically. (Your timestamp will differ, and notice it is **UTC**, not local time — a feature, not a bug: store UTC, convert on display.) The pattern `DEFAULT 'open'` + CHECK whitelist + `DEFAULT CURRENT_TIMESTAMP` is the standard skeleton for any workflow table.

## 6. Foreign keys and referential actions

A foreign key declares that a child column's values must exist in a parent table: `orders.customer_id REFERENCES customers(customer_id)` means no order can point at a ghost customer. But in SQLite there is a historical trap you must burn into memory:

**SQLite does not enforce foreign keys unless the connection has run `PRAGMA foreign_keys = ON;` — and the setting resets with every new connection.**

The default is OFF for backwards compatibility. Pitfall 1 below shows how spooky that gets; here we work with enforcement on, which is what the pragma at the top of each block guarantees. (Put `PRAGMA foreign_keys = ON;` in your `~/.sqliterc` so interactive sessions always have it.)

The interesting design decision is what happens to children when the parent row is **deleted** (or its key updated). You choose per foreign key with `ON DELETE` / `ON UPDATE`:

| action | on parent delete, the child rows... | typical use |
|---|---|---|
| `NO ACTION` (default) / `RESTRICT` | block the delete | financial records: never orphan, never auto-destroy |
| `CASCADE` | are deleted too | pure detail rows that mean nothing without the parent |
| `SET NULL` | keep existing, FK column becomes NULL | "history survives, the link is severed" |

(`RESTRICT` and the default `NO ACTION` differ only in timing subtleties inside deferred transactions; day-to-day they behave alike. Being explicit with `RESTRICT` documents intent.)

Let's build marketing's campaign tables and choose an action for each relationship:

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE promo_campaigns (
    campaign_id INTEGER PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    starts_on   TEXT NOT NULL,
    ends_on     TEXT NOT NULL,
    CHECK (ends_on >= starts_on)
);

CREATE TABLE campaign_products (
    campaign_id INTEGER NOT NULL
                REFERENCES promo_campaigns(campaign_id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL
                REFERENCES products(product_id) ON DELETE RESTRICT,
    PRIMARY KEY (campaign_id, product_id)
);

CREATE TABLE stock_alerts (
    alert_id   INTEGER PRIMARY KEY,
    product_id INTEGER REFERENCES products(product_id) ON DELETE SET NULL,
    email      TEXT NOT NULL
);
```

```text
(no output — three tables created)
```

The reasoning: a campaign's product list is meaningless without the campaign (**CASCADE**); a product must not be deletable while a live campaign advertises it (**RESTRICT**); and a back-in-stock alert should survive as a record even if the product goes away — with the link nulled (**SET NULL**; note the FK column must be nullable for that to be possible).

Seed some data, including a throwaway test product to delete later:

```sql
PRAGMA foreign_keys = ON;

INSERT INTO products (product_id, sku, name, category_id, supplier_id,
                      unit_price, unit_cost, is_active, introduced_at)
VALUES (9001, 'NK-TEST-9001', 'Prototype Lantern', 7, 1,
        59.90, 21.50, 1, '2026-07-01');

INSERT INTO promo_campaigns (name, starts_on, ends_on)
VALUES ('Midsummer Sale', '2026-06-15', '2026-06-30');

INSERT INTO campaign_products (campaign_id, product_id) VALUES (1, 9001), (1, 12), (1, 25);

INSERT INTO stock_alerts (product_id, email)
VALUES (9001, 'kirsten.holm@example.org');

SELECT cp.campaign_id, cp.product_id, p.name
FROM campaign_products cp
JOIN products p USING (product_id);
```

```text
╭─────────────┬────────────┬──────────────────────╮
│ campaign_id │ product_id │         name         │
╞═════════════╪════════════╪══════════════════════╡
│           1 │       9001 │ Prototype Lantern    │
│           1 │         12 │ Fjell Ski Bindings   │
│           1 │         25 │ Flake Snowshoes 30in │
╰─────────────┴────────────┴──────────────────────╯
```

**RESTRICT in action** — the prototype is in a campaign, so it cannot be deleted:

```sql
-- BAD: the product is still referenced by a campaign — RESTRICT blocks the delete
PRAGMA foreign_keys = ON;
DELETE FROM products WHERE product_id = 9001;
```

```text
Error near line 3: FOREIGN KEY constraint failed
```

**SET NULL in action** — unlink it from the campaign first, then delete; the stock alert survives with its product reference nulled:

```sql
PRAGMA foreign_keys = ON;

DELETE FROM campaign_products WHERE product_id = 9001;  -- unlink first
DELETE FROM products          WHERE product_id = 9001;  -- now allowed

SELECT alert_id, product_id, email FROM stock_alerts;
```

```text
╭──────────┬────────────┬──────────────────────────╮
│ alert_id │ product_id │          email           │
╞══════════╪════════════╪══════════════════════════╡
│        1 │            │ kirsten.holm@example.org │
╰──────────┴────────────┴──────────────────────────╯
```

**CASCADE in action** — delete the campaign, and its remaining product links vanish with it:

```sql
PRAGMA foreign_keys = ON;

DELETE FROM promo_campaigns WHERE name = 'Midsummer Sale';

SELECT COUNT(*) AS remaining_links FROM campaign_products;
```

```text
╭─────────────────╮
│ remaining_links │
╞═════════════════╡
│               0 │
╰─────────────────╯
```

Choose actions consciously. CASCADE on the wrong relationship is a chainsaw — `orders REFERENCES customers ON DELETE CASCADE` would mean "deleting a customer silently destroys their entire order history." For anything money-related, RESTRICT is almost always right: force the human to deal with the children explicitly.

> **PostgreSQL note:** foreign keys are always enforced — there is no pragma and no way to accidentally run without them. PostgreSQL also supports `ON DELETE SET DEFAULT` and deferrable constraints (checked at COMMIT rather than per statement).

## 7. Generated columns — computed once, in the schema

Module 5 had you retype `quantity * unit_price * (1 - discount_pct / 100.0)` — the canonical **item revenue** — over and over. A **generated column** bakes a formula into the table so every reader gets the same, always-consistent value:

```sql
CREATE TABLE order_items_v2 (
    order_id     INTEGER NOT NULL REFERENCES orders(order_id),
    product_id   INTEGER NOT NULL REFERENCES products(product_id),
    quantity     INTEGER NOT NULL CHECK (quantity > 0),
    unit_price   REAL    NOT NULL CHECK (unit_price >= 0),
    discount_pct INTEGER NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    line_total   REAL    GENERATED ALWAYS AS
                 (ROUND(quantity * unit_price * (1 - discount_pct / 100.0), 2)) STORED,
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO order_items_v2 (order_id, product_id, quantity, unit_price, discount_pct)
SELECT order_id, product_id, quantity, unit_price, discount_pct
FROM order_items;

SELECT order_id, product_id, quantity, unit_price, discount_pct, line_total
FROM order_items_v2
ORDER BY line_total DESC
LIMIT 5;
```

```text
╭──────────┬────────────┬──────────┬────────────┬──────────────┬────────────╮
│ order_id │ product_id │ quantity │ unit_price │ discount_pct │ line_total │
╞══════════╪════════════╪══════════╪════════════╪══════════════╪════════════╡
│      629 │        241 │        4 │     834.53 │            0 │    3338.12 │
│     1374 │         46 │        3 │    1004.85 │            0 │    3014.55 │
│     2382 │         46 │        3 │    1004.85 │            0 │    3014.55 │
│     2653 │         46 │        3 │    1004.85 │            0 │    3014.55 │
│     4718 │         46 │        3 │    1004.85 │            0 │    3014.55 │
╰──────────┴────────────┴──────────┴────────────┴──────────────┴────────────╯
```

All 13,475 line totals computed themselves during the copy (the biggest single order line ever: four avalanche beacons). Two flavors exist: `STORED` computes on write and occupies disk; `VIRTUAL` (the default) computes on every read. Use STORED for values read far more often than written — like revenue.

The formula is the single source of truth, and you cannot contradict it:

```sql
-- BAD: you cannot write to a generated column
INSERT INTO order_items_v2 (order_id, product_id, quantity, unit_price, discount_pct, line_total)
VALUES (1, 9001, 1, 100, 0, 999999);
```

```text
Parse error near line 2: cannot INSERT into generated column "line_total"
```

That error is a feature: a `line_total` that could disagree with its own inputs would be worse than no column at all. Generated expressions must be deterministic and row-local (no subqueries, no `random()`, no `'now'`).

> **PostgreSQL note:** same syntax, but PostgreSQL supports only `STORED` (no virtual generated columns until PG 18's `VIRTUAL`).

## 8. ALTER TABLE — what SQLite can do, and the recreate pattern for the rest

SQLite's `ALTER TABLE` does exactly four things: `RENAME TO` (rename table), `RENAME COLUMN`, `ADD COLUMN`, `DROP COLUMN`. Two in action — procurement wants to flag preferred suppliers, and support prefers "subject" over "topic":

```sql
ALTER TABLE suppliers
    ADD COLUMN preferred INTEGER NOT NULL DEFAULT 0 CHECK (preferred IN (0, 1));

SELECT supplier_id, name, preferred FROM suppliers LIMIT 3;
```

```text
╭─────────────┬─────────────────────┬───────────╮
│ supplier_id │        name         │ preferred │
╞═════════════╪═════════════════════╪═══════════╡
│           1 │ Fjellutstyr AS      │         0 │
│           2 │ Nordic Trail Supply │         0 │
│           3 │ Alpin Werke GmbH    │         0 │
╰─────────────┴─────────────────────┴───────────╯
```

All 40 existing suppliers instantly have `preferred = 0` — an added `NOT NULL` column *must* carry a constant DEFAULT for exactly this reason. (Limits of ADD COLUMN: the default must be a constant, and the new column cannot be `UNIQUE` or `PRIMARY KEY`.)

```sql
ALTER TABLE support_tickets RENAME COLUMN topic TO subject;

SELECT sql FROM sqlite_schema WHERE name = 'support_tickets';
```

```text
╭────────────────────────────────────────────────────────────────╮
│                              sql                               │
╞════════════════════════════════════════════════════════════════╡
│ CREATE TABLE support_tickets (                                 │
│     ticket_id INTEGER PRIMARY KEY,                             │
│     order_id  INTEGER NOT NULL REFERENCES orders(order_id),    │
│     subject     TEXT    NOT NULL,                              │
│     status    TEXT    NOT NULL DEFAULT 'open'                  │
│               CHECK (status IN ('open', 'pending', 'closed')), │
│     opened_at TEXT    NOT NULL DEFAULT CURRENT_TIMESTAMP       │
│ )                                                              │
╰────────────────────────────────────────────────────────────────╯
```

(SQLite edits the stored `CREATE TABLE` text in place — you can see the slightly ragged whitespace where `topic` became `subject`.)

Everything else — changing a column's type, adding a CHECK or UNIQUE to an existing column, dropping a constraint, reordering columns — has **no ALTER syntax in SQLite**. The official manual prescribes a 12-step "recreate" procedure; its load-bearing core is five steps:

1. `PRAGMA foreign_keys = OFF;` — so the table swap doesn't trip other tables' FKs mid-flight
2. `BEGIN;` a transaction (Module 9 covers these properly — for now: it makes the whole dance all-or-nothing)
3. `CREATE TABLE new_table (...)` with the schema you *wish* you had, then `INSERT INTO new_table SELECT ... FROM old_table;`
4. `DROP TABLE old_table;` then `ALTER TABLE new_table RENAME TO old_table;`
5. `COMMIT;`, re-enable foreign keys, and run `PRAGMA foreign_key_check;` to prove you broke nothing

Real migration: the finance team decrees that zero-amount payments are always errors, so `payments.amount` needs a `CHECK (amount <> 0)`:

```sql
PRAGMA foreign_keys = OFF;

BEGIN;

CREATE TABLE payments_new (
    payment_id INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    amount     REAL NOT NULL CHECK (amount <> 0),
    method     TEXT NOT NULL CHECK (method IN
                   ('card', 'paypal', 'klarna', 'bank_transfer', 'refund')),
    status     TEXT NOT NULL CHECK (status IN ('pending', 'captured', 'failed')),
    paid_at    TEXT NOT NULL
);

INSERT INTO payments_new
SELECT payment_id, order_id, amount, method, status, paid_at
FROM payments;

DROP TABLE payments;

ALTER TABLE payments_new RENAME TO payments;

COMMIT;

PRAGMA foreign_keys = ON;
PRAGMA foreign_key_check;

SELECT COUNT(*) AS payments_migrated FROM payments;
```

```text
╭───────────────────╮
│ payments_migrated │
╞═══════════════════╡
│              6167 │
╰───────────────────╯
```

All 6,167 payments came through, `foreign_key_check` returned no rows (silence is success), and — a nice property of this pattern — the `INSERT ... SELECT` re-validated every historical row against the new CHECK as it copied. Had any zero-amount payment existed, the migration itself would have failed, inside the transaction, changing nothing. The new constraint is live:

```sql
-- BAD: a zero-amount payment no longer sneaks through
INSERT INTO payments (order_id, amount, method, status, paid_at)
VALUES (4001, 0, 'card', 'captured', '2026-07-15 11:00:00');
```

```text
Error near line 2: CHECK constraint failed: amount <> 0
```

The full 12-step version in the SQLite docs adds: capture and recreate the table's indexes, triggers, and views, and check `PRAGMA legacy_alter_table`. The five steps above are the skeleton you'll actually type; remember indexes-and-views as the checklist item people forget.

> **PostgreSQL note:** `ALTER TABLE` is far richer — `ALTER COLUMN ... TYPE`, `SET NOT NULL`, `ADD CONSTRAINT`, `DROP CONSTRAINT` all exist, so most migrations are one statement and the recreate dance is rarely needed. The *discipline* transfers, though: schema changes in transactions, verified before and after.

## 9. DROP TABLE, and why IF EXISTS matters

`DROP TABLE` deletes a table and all its rows, permanently. The `IF EXISTS` variant succeeds silently when the table is already gone — which is what makes setup/teardown scripts **idempotent** (safe to run twice), a property Module 9 elevates to a design principle:

```sql
DROP TABLE IF EXISTS affinity_demo;
DROP TABLE IF EXISTS unicorn_inventory;   -- doesn't exist: IF EXISTS makes this a no-op

SELECT COUNT(*) AS still_there
FROM sqlite_schema
WHERE name IN ('affinity_demo', 'unicorn_inventory');
```

```text
╭─────────────╮
│ still_there │
╞═════════════╡
│           0 │
╰─────────────╯
```

Without `IF EXISTS`, the second statement would error and abort your script. With it, "make sure this table is gone" works from any starting state. (With foreign keys ON, you cannot drop a parent table while child rows reference it — another reason the recreate pattern disables the pragma first.)

## 10. TEMP tables — private scratch space

`CREATE TEMP TABLE` makes a table that only your connection can see, and that vanishes when the connection closes. Perfect for interactive analysis: materialize an intermediate result once, poke at it from several angles, leave no trace.

```sql
CREATE TEMP TABLE nordic_customers AS
SELECT customer_id, country
FROM customers
WHERE country IN ('Norway', 'Sweden', 'Denmark', 'Finland');

SELECT country, COUNT(*) AS customers
FROM nordic_customers
GROUP BY country
ORDER BY customers DESC;
```

```text
╭─────────┬───────────╮
│ country │ customers │
╞═════════╪═══════════╡
│ Sweden  │       175 │
│ Denmark │       101 │
│ Norway  │        98 │
│ Finland │        65 │
╰─────────┴───────────╯
```

And here is the per-connection scope made visible — because each one-shot `sqlite3` invocation is a new connection, the temp table is already gone by the next block:

```sql
-- BAD: the temp table died with the previous connection
SELECT COUNT(*) FROM nordic_customers;
```

```text
Parse error near line 2: no such table: nordic_customers
```

In an interactive session both statements share one connection, so the second would work fine there. Rule of thumb: TEMP tables for *within-session* scratch work; for anything that must outlive the session, a real table or a view.

## 11. CREATE TABLE AS SELECT — snapshots

That TEMP example already smuggled in the syntax: `CREATE TABLE ... AS SELECT` (CTAS) creates a table *from a query result*. Non-temp CTAS is how you take a persistent **snapshot** — say, freezing monthly gross revenue (canonical definition: item revenue summed over non-cancelled orders) before a pricing experiment:

```sql
CREATE TABLE monthly_revenue_snapshot AS
SELECT
    strftime('%Y-%m', o.ordered_at) AS month,
    COUNT(DISTINCT o.order_id)      AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
                                    AS gross_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY month;

SELECT * FROM monthly_revenue_snapshot ORDER BY month DESC LIMIT 3;
```

```text
╭─────────┬────────┬───────────────╮
│  month  │ orders │ gross_revenue │
╞═════════╪════════╪═══════════════╡
│ 2026-07 │    363 │     181073.95 │
│ 2026-06 │    570 │     288614.97 │
│ 2026-05 │    436 │     234748.78 │
╰─────────┴────────┴───────────────╯
```

CTAS is fast and convenient, but inspect what it actually created:

```sql
SELECT sql FROM sqlite_schema WHERE name = 'monthly_revenue_snapshot';
```

```text
╭────────────────────────────────────────╮
│                  sql                   │
╞════════════════════════════════════════╡
│ CREATE TABLE monthly_revenue_snapshot( │
│   month,                               │
│   orders,                              │
│   gross_revenue                        │
│ )                                      │
╰────────────────────────────────────────╯
```

Column names only — **no types, no PRIMARY KEY, no NOT NULL, no CHECKs**. CTAS copies data, never constraints. For a throwaway snapshot that's fine; for a table with a future, write the full `CREATE TABLE` and load it with `INSERT ... SELECT` (as we did for `order_items_v2`). And remember the deeper limitation: a snapshot is frozen the moment you create it. Which brings us to views.

## 12. Views — the canonical query, saved

A **view** is a named query stored in the schema. It holds *no data*: every time you select from it, the underlying query runs against the live tables. This makes views the right tool for the most important consistency problem in analytics: making sure everyone computes revenue the same way.

Let's encode this course's canonical metric definitions — item revenue per line, order total = item revenue + shipping — once and for all:

```sql
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

SELECT * FROM v_order_revenue ORDER BY order_id LIMIT 3;
```

```text
╭──────────┬─────────────┬───────────┬─────────────────────┬──────────────┬───────────────┬─────────────╮
│ order_id │ customer_id │  status   │     ordered_at      │ item_revenue │ shipping_cost │ order_total │
╞══════════╪═════════════╪═══════════╪═════════════════════╪══════════════╪═══════════════╪═════════════╡
│        1 │         490 │ delivered │ 2026-03-01 22:15:44 │      3660.37 │           4.9 │     3665.27 │
│        2 │         514 │ cancelled │ 2023-08-23 13:27:07 │        219.5 │           9.9 │       229.4 │
│        3 │         321 │ shipped   │ 2026-07-07 18:14:23 │       712.22 │           0.0 │      712.22 │
╰──────────┴─────────────┴───────────┴─────────────────────┴──────────────┴───────────────┴─────────────╯
```

One design decision worth defending: the view keeps `status` and does **not** filter out cancelled orders. A view this central should stay policy-free — different metrics need different filters (gross revenue excludes cancelled; AOV averages over non-cancelled; a cancellation-rate report needs the cancelled rows themselves). Callers apply their own WHERE. Watch how clean the canonical metrics become:

```sql
SELECT
    strftime('%Y', ordered_at) AS year,
    COUNT(*)                   AS orders,
    ROUND(SUM(item_revenue), 2) AS gross_revenue,
    ROUND(AVG(order_total), 2)  AS aov
FROM v_order_revenue
WHERE status <> 'cancelled'
GROUP BY year
ORDER BY year;
```

```text
╭──────┬────────┬───────────────┬────────╮
│ year │ orders │ gross_revenue │  aov   │
╞══════╪════════╪═══════════════╪════════╡
│ 2023 │    326 │     172717.76 │ 535.22 │
│ 2024 │    908 │     468681.54 │ 521.86 │
│ 2025 │   2030 │    1129344.73 │ 562.08 │
│ 2026 │   2421 │    1315996.88 │ 549.26 │
╰──────┴────────┴───────────────┴────────╯
```

Gross revenue and AOV by year, per the canonical definitions, in ten lines that contain no arithmetic — the formula lives in exactly one place. If the discount rules ever change, you fix the view and every downstream query is instantly correct.

Now the crucial contrast with the CTAS snapshot: a view is always live. Insert a brand-new order and query both:

```sql
INSERT INTO orders (order_id, customer_id, address_id, status, shipping_cost, ordered_at)
VALUES (9001, 1, 1, 'paid', 49.0, '2026-07-15 09:30:00');

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct)
VALUES (9001, 12, 2, 189.95, 10);

SELECT order_id, item_revenue, shipping_cost, order_total
FROM v_order_revenue
WHERE order_id = 9001;
```

```text
╭──────────┬──────────────┬───────────────┬─────────────╮
│ order_id │ item_revenue │ shipping_cost │ order_total │
╞══════════╪══════════════╪═══════════════╪═════════════╡
│     9001 │       341.91 │          49.0 │      390.91 │
╰──────────┴──────────────┴───────────────┴─────────────╯
```

The view sees order 9001 immediately — no refresh, no reload. The snapshot, meanwhile, still believes July has 363 orders:

```sql
SELECT month, orders, gross_revenue
FROM monthly_revenue_snapshot
WHERE month = '2026-07';
```

```text
╭─────────┬────────┬───────────────╮
│  month  │ orders │ gross_revenue │
╞═════════╪════════╪═══════════════╡
│ 2026-07 │    363 │     181073.95 │
╰─────────┴────────┴───────────────╯
```

That's the whole trade-off in one pair of results: views are always current but re-run their query every time (a heavy view queried often can hurt — Module 10); CTAS is instant to read but frozen at creation. Views also have a one-way valve:

```sql
-- BAD: a view is a saved query, not a table you can write to
UPDATE v_order_revenue SET order_total = 0 WHERE order_id = 9001;
```

```text
Parse error near line 2: cannot modify v_order_revenue because it is a view
```

In SQLite, views are read-only, period (there's an advanced escape hatch — `INSTEAD OF` triggers — beyond this course). Drop one with `DROP VIEW IF EXISTS name;` — the underlying tables are untouched.

> **PostgreSQL note:** PostgreSQL additionally offers `CREATE MATERIALIZED VIEW` — a view that *does* store its result like CTAS, refreshed on demand with `REFRESH MATERIALIZED VIEW`. It's the standard middle ground for expensive analytics queries: snapshot performance, view semantics, explicit staleness. (Simple PG views are also auto-updatable in some cases; SQLite's never are.)

## Pitfalls

### Pitfall 1 — foreign keys silently unenforced

The scariest default in SQLite. Open a fresh connection, forget the pragma, and referential integrity simply... isn't. Customer 424242 does not exist:

```sql
-- BAD: customer 424242 does not exist, yet the insert succeeds
INSERT INTO orders (order_id, customer_id, address_id, status, shipping_cost, ordered_at)
VALUES (9099, 424242, 424242, 'pending', 0, '2026-07-15 12:00:00');

SELECT changes() AS rows_inserted;
```

```text
╭───────────────╮
│ rows_inserted │
╞═══════════════╡
│             1 │
╰───────────────╯
```

No error. No warning. An order now points at a ghost customer *and* a ghost address, in a table whose DDL plainly says `REFERENCES customers(customer_id)`. The declaration is real; the enforcement was off. `PRAGMA foreign_key_check` audits existing data for exactly this damage:

```sql
PRAGMA foreign_key_check(orders);
```

```text
╭────────┬───────┬───────────┬──────╮
│ table  │ rowid │  parent   │ fkid │
╞════════╪═══════╪═══════════╪══════╡
│ orders │  9099 │ addresses │    0 │
│ orders │  9099 │ customers │    1 │
╰────────┴───────┴───────────┴──────╯
```

Row 9099 violates both foreign keys. With enforcement on, the identical insert is refused:

```sql
-- BAD: same insert, but with enforcement switched on — now it is refused
PRAGMA foreign_keys = ON;

INSERT INTO orders (order_id, customer_id, address_id, status, shipping_cost, ordered_at)
VALUES (9100, 424242, 424242, 'pending', 0, '2026-07-15 12:00:00');
```

```text
Error near line 4: FOREIGN KEY constraint failed
```

Clean up the orphan and verify with both the pragma and a Module 4 anti-join:

```sql
DELETE FROM orders WHERE order_id = 9099;   -- remove the orphan

PRAGMA foreign_key_check(orders);

SELECT COUNT(*) AS orphans_left
FROM orders o
LEFT JOIN customers c USING (customer_id)
WHERE c.customer_id IS NULL;
```

```text
╭──────────────╮
│ orphans_left │
╞══════════════╡
│            0 │
╰──────────────╯
```

(`foreign_key_check` printed nothing — no violations.) The fix, permanently: `PRAGMA foreign_keys = ON;` in `~/.sqliterc`, at the top of every script that writes, and in your application's connection setup. And when you inherit a SQLite database, run `PRAGMA foreign_key_check;` before trusting a single join.

### Pitfall 2 — type affinity accepts garbage, then sorts it weirdly

Marketing tracks loyalty points; a CSV export feeds the table:

```sql
CREATE TABLE loyalty_points (
    customer_id INTEGER PRIMARY KEY,
    points      INTEGER NOT NULL
);

INSERT INTO loyalty_points VALUES (1, 120), (2, 45), (3, 300);
```

```text
(no output — table created, three rows inserted)
```

One day the export ships a mangled value:

```sql
-- BAD: a CSV import hands us '95 pts' — SQLite stores it as TEXT without complaint
INSERT INTO loyalty_points VALUES (4, '95 pts');

SELECT customer_id, points, typeof(points)
FROM loyalty_points
ORDER BY points DESC;
```

```text
╭─────────────┬────────┬────────────────╮
│ customer_id │ points │ typeof(points) │
╞═════════════╪════════╪════════════════╡
│           4 │ 95 pts │ text           │
│           3 │    300 │ integer        │
│           1 │    120 │ integer        │
│           2 │     45 │ integer        │
╰─────────────┴────────┴────────────────╯
```

Two failures in one box. The insert succeeded — `'95 pts'` isn't losslessly convertible to an integer, so SQLite stored it as TEXT inside the INTEGER column. And the "top customers by points" ranking is now wrong: in SQLite's cross-type ordering, every TEXT value sorts after every number, so 95 points beat 300. `SUM(points)` would quietly treat it as 0-ish garbage too. The fix is the one from §3 — STRICT:

```sql
CREATE TABLE loyalty_points_strict (
    customer_id INTEGER PRIMARY KEY,
    points      INTEGER NOT NULL
) STRICT;

INSERT INTO loyalty_points_strict
SELECT customer_id, points FROM loyalty_points WHERE customer_id <= 3;
```

```text
(no output — strict table created and loaded with the three clean rows)
```

```sql
-- BAD: STRICT turns the silent corruption into an immediate error
INSERT INTO loyalty_points_strict VALUES (4, '95 pts');
```

```text
Error near line 2: cannot store TEXT value in INTEGER column loyalty_points_strict.points
```

The bad row is rejected at load time — the CSV problem becomes the exporter's bug to fix, not your analytics team's mystery. On tables you can't make STRICT, `CHECK (typeof(points) = 'integer')` achieves the same per column.

### Pitfall 3 — UNIQUE happily allows many NULLs

Intuition says a UNIQUE column can hold each value once, so surely two NULLs collide? No — NULL is not *equal* to anything, including another NULL (Module 2's three-valued logic reaching into DDL):

```sql
CREATE TABLE newsletter_subscribers (
    subscriber_id INTEGER PRIMARY KEY,
    email         TEXT UNIQUE,
    phone         TEXT UNIQUE
);
```

```text
(no output — table created)
```

```sql
-- BAD: three subscribers with no phone — UNIQUE(phone) stops none of them
INSERT INTO newsletter_subscribers (email, phone) VALUES
    ('anna@example.org',  NULL),
    ('bjorn@example.org', NULL),
    ('cato@example.org',  NULL);

SELECT COUNT(*) AS null_phone_rows
FROM newsletter_subscribers
WHERE phone IS NULL;
```

```text
╭─────────────────╮
│ null_phone_rows │
╞═════════════════╡
│               3 │
╰─────────────────╯
```

Three rows, three NULL phones, zero violations. Often that's exactly right — `customers.phone`-style optional fields *should* allow many unknowns. The pitfall is relying on `UNIQUE` alone for an identifier that must always exist: a nullable UNIQUE key lets unlimited "blank" rows through. If a value is mandatory *and* unique, say both: `email TEXT NOT NULL UNIQUE` — as the real `customers` table does. (For "unique among non-NULL rows only, expressed deliberately", partial indexes do it elegantly — Module 10.)

> **PostgreSQL note:** the same NULL behavior is the default (`UNIQUE NULLS DISTINCT`); since PG 15 you can opt out with `UNIQUE NULLS NOT DISTINCT`, which allows at most one NULL.

### Pitfall 4 — CHECK constraints validate writes, not existing data

A CHECK constraint is a bouncer at the door, not a detective inside the club: it inspects rows as they are written and **never re-examines rows already in the table**. Bad data can predate the constraint (bulk loads with checks disabled, Postgres `NOT VALID` migrations, restored dumps) and sit there indefinitely:

```sql
CREATE TABLE promo_budgets (
    campaign TEXT PRIMARY KEY,
    budget   REAL NOT NULL CHECK (budget > 0)
);

INSERT INTO promo_budgets VALUES ('spring_sale', 15000);
```

```text
(no output — table created, one valid row)
```

```sql
-- BAD: a bulk load with checks disabled sneaks in an impossible budget
PRAGMA ignore_check_constraints = ON;
INSERT INTO promo_budgets VALUES ('winter_flop', -500);
PRAGMA ignore_check_constraints = OFF;

SELECT * FROM promo_budgets;
```

```text
╭─────────────┬─────────╮
│  campaign   │ budget  │
╞═════════════╪═════════╡
│ spring_sale │ 15000.0 │
│ winter_flop │  -500.0 │
╰─────────────┴─────────╯
```

A −500 budget lives in a table whose DDL swears `budget > 0`, and every SELECT will serve it without complaint — reads never check anything. The row is a landmine, and it detonates at the worst time: months later, when someone touches it —

```sql
-- BAD: months later, finance tops the campaign up — and THEN it explodes
UPDATE promo_budgets SET budget = budget + 400 WHERE campaign = 'winter_flop';
```

```text
Error near line 2: CHECK constraint failed: budget > 0
```

A perfectly reasonable-looking UPDATE fails because of a value some batch job wrote long ago (−500 + 400 = −100, still invalid — the write re-fires the check). Note the asymmetry: the row was *readable* forever and only became *untouchable* on write. To hunt for dormant violations proactively:

```sql
PRAGMA integrity_check(promo_budgets);
```

```text
╭──────────────────────────────────────────╮
│             integrity_check              │
╞══════════════════════════════════════════╡
│ CHECK constraint failed in promo_budgets │
╰──────────────────────────────────────────╯
```

`integrity_check` re-validates stored rows against NOT NULL, CHECK, and UNIQUE — run it (plus `foreign_key_check`) on any database you inherit. Then repair:

```sql
DELETE FROM promo_budgets WHERE budget <= 0;

PRAGMA integrity_check(promo_budgets);
```

```text
╭─────────────────╮
│ integrity_check │
╞═════════════════╡
│ ok              │
╰─────────────────╯
```

The general lesson: a constraint in the DDL is a promise about *future writes*. Whether the *existing* data honors it is a separate question with a separate tool. (Our §8 migration got this right for free: `INSERT ... SELECT` through the new table's constraints re-validated every row.)

> **PostgreSQL note:** `ALTER TABLE ... ADD CONSTRAINT ... CHECK (...)` *does* scan and validate existing rows by default — unless you add `NOT VALID`, which skips the scan and creates exactly the dormant-violation situation above until you run `VALIDATE CONSTRAINT`.

## Exercises

Work on your copy (`/tmp/sqlab/scratch.db`) with `PRAGMA foreign_keys = ON;` in every session. Exercises assume you have run this module's blocks in order (so `v_order_revenue`, `support_tickets`, and the `suppliers.preferred` column exist). No answers here — solutions live in `solutions/08-ddl-constraints-views.md`.

**Warm-up**

1. Nordkart is opening physical showrooms. Create a `showrooms` table — as a STRICT table — with: an auto-assigned integer primary key `showroom_id`; `name` (required, no two showrooms may share a name); `country` and `city` (required); `opened_on` (optional ISO date); and `is_flagship` (required 0/1 flag, defaulting to 0, with a CHECK enforcing the two allowed values). Insert one flagship in Oslo, letting every defaultable column default, and select the row back to confirm.

2. Prediction drill — for each statement below, *first* write down whether it succeeds or which constraint stops it, then run it against your copy to check (foreign keys ON):
   a) inserting a new customer whose email equals an existing customer's email;
   b) inserting a product with `unit_price = -1`;
   c) inserting an order that omits `shipping_cost` (all other columns valid).
   Clean up anything that succeeded.

3. Customers can ask questions on product pages. Create `product_questions` with: `question_id` auto-assigned PK; `product_id` and `customer_id` (both required, with foreign keys to the real tables); `question` (required); `asked_at` defaulting to the current timestamp; `is_public` (0/1, default 1, CHECK-enforced). Insert one question supplying only `product_id`, `customer_id`, and `question`, and select it back to show the three defaults that filled themselves in.

**Core**

4. Implement the gift-card design from Module 7 with full constraints: `gift_cards` (`gift_card_id` PK; `code` required and unique; `initial_value` required, > 0; `balance` required, between 0 and `initial_value` inclusive; `purchased_by` optional FK to `customers` that becomes NULL if the customer is deleted; `issued_at` defaulting to the current timestamp; `status` required, whitelist `'active'`/`'redeemed'`/`'expired'`, default `'active'`) and `gift_card_redemptions` (`redemption_id` PK; `gift_card_id` required FK that deletes redemptions when the card is deleted; `order_id` required FK to `orders` that blocks deleting an order with redemptions; `amount` required, > 0; `redeemed_at` defaulting to the current timestamp). Then prove one CHECK works: try to insert a card whose `balance` exceeds its `initial_value`.

5. Implement the wishlist design from Module 7: `wishlists` (PK; required FK to `customers` such that deleting a customer deletes their wishlists; required `name`; a customer cannot have two wishlists with the same name; created-at default) and `wishlist_items` (composite PK on wishlist + product; FK to `wishlists` cascading on delete; required FK to `products`; added-at default). Insert one wishlist with two items for customer 42, then delete the wishlist and show its items are gone.

6. Migration task: procurement wants every supplier to carry a required, unique short code like `SUP-007`. `ALTER TABLE ADD COLUMN` cannot add a UNIQUE column, so use the recreate pattern: rebuild `suppliers` with a `supplier_code TEXT NOT NULL UNIQUE` column, backfilled as `'SUP-'` followed by the zero-padded `supplier_id` (hint: `printf('SUP-%03d', supplier_id)`), keeping all existing columns (including `preferred` from §8) and all 40 rows. Finish with `PRAGMA foreign_key_check;` and show 3 rows of the result.

7. Build `v_monthly_revenue` **on top of** `v_order_revenue`: one row per calendar month with `month` (`YYYY-MM`), `orders`, `gross_revenue`, and `aov`, following the canonical definitions (which orders must be excluded?). Query it for all 2026 months so far, most recent first.

8. The merchandising team constantly asks for product margins. Create `products_v2` — same columns as `products` — plus a **stored generated column** `margin_pct` computing the margin percentage `ROUND((unit_price - unit_cost) / unit_price * 100, 1)`. Load it from `products` and list the 5 highest-margin *active* products (name, unit_price, unit_cost, margin_pct).

**Challenge**

9. FK-action prediction drill, using your exercise-4 tables. Seed: one gift card purchased by customer 500, with one redemption against order 3000. For each scenario, predict the outcome (blocked? cascaded? nulled?), then run it (foreign keys ON!):
   a) `DELETE FROM orders WHERE order_id = 3000;`
   b) `DELETE FROM gift_cards WHERE gift_card_id = <your card id>;` — what happens to the redemption?
   Explain why (a) and (b) behave differently, citing the actions you declared. (Don't try deleting customer 500 — every real customer is referenced by `addresses`/`orders` rows whose FKs say NO ACTION, so the SET NULL on `purchased_by` never gets a chance. What *would* happen if those references didn't exist?)

10. Product management wants a new order status, `'refund_pending'`, between delivery and return. The status whitelist is a CHECK constraint baked into `orders` — no ALTER can touch it. Perform the full recreate dance on `orders` (a table referenced by `order_items`, `payments`, `shipments`, and your `support_tickets`!): new table with the 7-value whitelist, copy all rows, swap names, then prove integrity with `PRAGMA foreign_key_check;` and prove the new status works by updating one `'delivered'` order to `'refund_pending'`. (If the rename step fails with an error mentioning a view, you have just discovered — the honest way — why the official 12-step procedure includes "drop and recreate dependent views". Handle it.)

11. Build `v_customer_health` for the retention team: one row per customer who has ever ordered, with `customer_id`, `orders` (non-cancelled order count), `lifetime_revenue` (sum of non-cancelled order totals), and `last_order_at` (latest `ordered_at`, cancelled included — it's still activity). Build it on `v_order_revenue`, then show the top 5 customers by lifetime revenue.

## Key takeaways

- **`CREATE TABLE`** = column defs (+ column constraints) + table constraints (needed for anything multi-column, e.g. `PRIMARY KEY (a, b)`, `UNIQUE (a, b)`).
- **Affinity, not types**: ordinary SQLite columns coerce when lossless and otherwise store the value as-is — `'abc'` fits in an INTEGER column. `typeof(x)` reveals the truth. **`) STRICT;` enforces types** — use it for every new table. PostgreSQL enforces types always.
- **`INTEGER PRIMARY KEY`** aliases the rowid → auto-assigns `max+1`; deleted max ids can be **reused**; `AUTOINCREMENT` prevents reuse at a small cost and is usually unnecessary. `WITHOUT ROWID` = table stored keyed by its real PK.
- **`CHECK`** = row-local business rules (whitelists, ranges). **`UNIQUE`** can be composite; it does **not** limit NULLs — pair with `NOT NULL` for mandatory identifiers. **`DEFAULT CURRENT_TIMESTAMP`** stamps arrivals in UTC.
- **Foreign keys need `PRAGMA foreign_keys = ON` per connection** — put it in `~/.sqliterc` and every script. Actions: `RESTRICT`/`NO ACTION` block, `CASCADE` deletes children, `SET NULL` severs the link (column must be nullable). Audit inherited data with `PRAGMA foreign_key_check;`.
- **Generated columns**: `GENERATED ALWAYS AS (expr) STORED|VIRTUAL` — one formula, unwritable, always consistent.
- **`ALTER TABLE`** (SQLite) = rename table/column, add/drop column only. Everything else: recreate pattern — FKs off → `BEGIN` → create new → `INSERT...SELECT` → drop old → rename → `COMMIT` → FKs on → `foreign_key_check`. Bonus: the copy re-validates old rows against new constraints.
- **`DROP TABLE IF EXISTS`** for idempotent scripts. **`TEMP` tables** die with the connection. **CTAS** copies data but **no constraints** — and is frozen at creation.
- **Views** = saved queries, zero stored data, always live, read-only in SQLite. Encode canonical metrics once (`v_order_revenue`) and filter per use. PostgreSQL adds `MATERIALIZED VIEW` + `REFRESH`.
- Constraints govern **future writes** only — `PRAGMA integrity_check` / `foreign_key_check` are how you interrogate the past.
