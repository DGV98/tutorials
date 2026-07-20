# Module 9 — DML & Transactions

Everything so far has been reading. A data engineer's other half of the job is
*writing*: loading feeds, backfilling tables, correcting bad rows, and doing all
of it without destroying production data. This module covers INSERT, UPDATE,
DELETE, UPSERT, and transactions — and, more importantly, the professional
discipline around them: dry-runs, staging tables, idempotent loads, and the
transaction habits that mean a botched statement costs you a `ROLLBACK` instead
of a career story.

## What you'll learn

- `INSERT`: single-row, multi-row, `INSERT ... SELECT` backfills, `DEFAULT VALUES`
- `RETURNING` — getting the rows you just wrote, without a second query
- `UPDATE` with expressions, with subqueries in the `WHERE`, and `UPDATE ... FROM` against another table
- `DELETE` with subqueries; `DELETE` without `WHERE` as the TRUNCATE-equivalent; the soft-delete alternative
- UPSERT: `INSERT ... ON CONFLICT DO UPDATE / DO NOTHING`, the `excluded.*` pseudo-table, and the SQLite `WHERE true` parser quirk
- Transactions: `BEGIN` / `COMMIT` / `ROLLBACK`, what an error mid-transaction actually does, and ACID in practical terms
- Isolation: SQLite's single-writer model and WAL; PostgreSQL's isolation levels and the lost-update problem
- The professional load pattern: CSV → staging table → assertion queries → upsert, all inside a transaction
- Idempotent loads — why "safe to run twice" is the defining property of a production job
- Safe-destructive-operation discipline: SELECT-first, dry-run counts, transaction wrapping, the LIMIT canary

## 9.1 Rule zero: work on a copy

This module writes to the database. **Never experiment with writes against a
database you care about.** Make a scratch copy in the course root and leave
`shop.db` untouched:

```bash
cp shop.db scratch.db
```

**Every `sql` block from here to the end of the module runs against
`scratch.db`**, e.g. `sqlite3 -box scratch.db` interactively, or
`sqlite3 -box scratch.db "<statement>"` from the shell. If you ever wreck the
copy, `cp shop.db scratch.db` again (or rebuild `shop.db` itself from
`data/seed.sql` — see DATASET.md).

One SQLite-specific reminder from Module 8: foreign keys are only enforced when
your connection runs `PRAGMA foreign_keys = ON;`. The statements in this module
all reference valid parent rows, but in real write sessions you should turn it
on first thing, every time.

## 9.2 INSERT

### 9.2.1 Single row

Nordkart signs a new Norwegian supplier. An `INSERT` names the table, the
columns, and the values:

```sql
INSERT INTO suppliers (name, country, contact_email)
VALUES ('Nordlys Gear AS', 'Norway', 'orders@nordlysgear.no');

SELECT last_insert_rowid() AS new_supplier_id;
```

```text
╭─────────────────╮
│ new_supplier_id │
╞═════════════════╡
│              41 │
╰─────────────────╯
```

Two things to notice:

- We **always list the columns explicitly**. `INSERT INTO suppliers VALUES (...)`
  also works, but it silently depends on column order — the first schema change
  breaks it, or worse, doesn't break it and loads data into the wrong columns.
- We omitted `supplier_id`. It's an `INTEGER PRIMARY KEY`, which in SQLite is an
  alias for the rowid, so SQLite assigns the next id automatically.
  `last_insert_rowid()` reports the id assigned by *this connection's* most
  recent insert.

> **PostgreSQL note:** auto-assigned keys come from
> `GENERATED ALWAYS AS IDENTITY` (or the older `SERIAL`) columns. Instead of
> `last_insert_rowid()`/`currval()`, idiomatic PostgreSQL uses
> `INSERT ... RETURNING`, which works in SQLite too — next section.

### 9.2.2 Multi-row INSERT

The new supplier ships two products. One statement, several row tuples — one
network round-trip, one atomic change:

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-21-0351', 'Fjell Dry Bag 30L', 21, 41, 34.90, 15.20, 1, '2026-07-15'),
    ('NK-25-0352', 'Fjell Wool Beanie', 25, 41, 24.50,  9.80, 1, '2026-07-15');

SELECT product_id, sku, name, unit_price
FROM products
WHERE supplier_id = 41;
```

```text
╭────────────┬────────────┬───────────────────┬────────────╮
│ product_id │    sku     │       name        │ unit_price │
╞════════════╪════════════╪═══════════════════╪════════════╡
│        351 │ NK-21-0351 │ Fjell Dry Bag 30L │       34.9 │
│        352 │ NK-25-0352 │ Fjell Wool Beanie │       24.5 │
╰────────────┴────────────┴───────────────────┴────────────╯
```

### 9.2.3 RETURNING — see what you wrote

`last_insert_rowid()` only reports one id, and only for plain inserts. The
modern tool is the `RETURNING` clause (SQLite 3.35+, PostgreSQL since 8.2): the
write statement itself returns the rows it produced, including auto-assigned
keys and defaults you didn't supply.

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-24-0353', 'Fjell Merino Socks', 24, 41, 18.90, 7.10, 1, '2026-07-15')
RETURNING product_id, sku, unit_price;
```

```text
╭────────────┬────────────┬────────────╮
│ product_id │    sku     │ unit_price │
╞════════════╪════════════╪════════════╡
│        353 │ NK-24-0353 │       18.9 │
╰────────────┴────────────┴────────────╯
```

`RETURNING` works on `UPDATE` and `DELETE` too (you'll see both shortly). It is
the difference between "I think I updated 3 rows" and "here are the 3 rows I
updated" — use it whenever the result matters.

### 9.2.4 INSERT ... SELECT — the backfill workhorse

Most production inserts don't come from literal `VALUES`; they come from other
queries. `INSERT INTO ... SELECT ...` populates a table from any query — this
is how you backfill reporting tables. Let's materialize order totals (the
canonical definition: item revenue + shipping) into a table the BI team can
read cheaply:

```sql
CREATE TABLE order_totals (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL,
    status        TEXT    NOT NULL,
    items_revenue REAL    NOT NULL,
    order_total   REAL    NOT NULL
);

INSERT INTO order_totals (order_id, customer_id, status, items_revenue, order_total)
SELECT
    o.order_id,
    o.customer_id,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2),
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) + o.shipping_cost, 2)
FROM orders o
JOIN order_items oi USING (order_id)
GROUP BY o.order_id;

SELECT COUNT(*) AS orders_loaded, ROUND(SUM(order_total), 2) AS sum_of_totals
FROM order_totals;
```

```text
╭───────────────┬───────────────╮
│ orders_loaded │ sum_of_totals │
╞═══════════════╪═══════════════╡
│          6000 │    3310821.96 │
╰───────────────┴───────────────╯
```

All 6,000 orders backfilled in one statement. Note the column list on the
`INSERT` side and matching expressions on the `SELECT` side — the pairing is
positional, so keep them visually aligned.

### 9.2.5 DEFAULT VALUES

When every column has a default (or is nullable), `INSERT ... DEFAULT VALUES`
creates a row of pure defaults. It shines for log/audit tables:

```sql
CREATE TABLE load_log (
    load_id    INTEGER PRIMARY KEY,
    started_at TEXT NOT NULL DEFAULT (datetime('now')),
    source     TEXT NOT NULL DEFAULT 'manual',
    note       TEXT
);

INSERT INTO load_log DEFAULT VALUES;

SELECT * FROM load_log;
```

```text
╭─────────┬─────────────────────┬────────┬──────╮
│ load_id │     started_at      │ source │ note │
╞═════════╪═════════════════════╪════════╪══════╡
│       1 │ 2026-07-15 23:52:56 │ manual │      │
╰─────────┴─────────────────────┴────────┴──────╯
```

(Your `started_at` will differ — it's the wall clock.) We'll use `load_log` for
real in the load pipeline in section 9.8.

## 9.3 UPDATE

### 9.3.1 SET from expressions — and SELECT first

The supplier for the Tide Dry Bag 10L raised costs, and merchandising wants its
price up 10%. **Discipline: before any UPDATE, run a SELECT with the exact same
WHERE clause.** You see which rows you're about to touch and what the new
values will be — before you commit to anything:

```sql
SELECT product_id, name, unit_price,
       ROUND(unit_price * 1.10, 2) AS proposed_price
FROM products
WHERE sku = 'NK-21-0006';
```

```text
╭────────────┬──────────────────┬────────────┬────────────────╮
│ product_id │       name       │ unit_price │ proposed_price │
╞════════════╪══════════════════╪════════════╪════════════════╡
│          6 │ Tide Dry Bag 10L │      21.64 │           23.8 │
╰────────────┴──────────────────┴────────────┴────────────────╯
```

One row, sensible number. Now the real thing, with `RETURNING` as the receipt:

```sql
UPDATE products
SET unit_price = ROUND(unit_price * 1.10, 2)
WHERE sku = 'NK-21-0006'
RETURNING product_id, sku, unit_price;
```

```text
╭────────────┬────────────┬────────────╮
│ product_id │    sku     │ unit_price │
╞════════════╪════════════╪════════════╡
│          6 │ NK-21-0006 │       23.8 │
╰────────────┴────────────┴────────────╯
```

The right-hand side of `SET` is any expression, and it reads the row's values
*as they were before the update* — so `unit_price * 1.10` is well-defined.

Strictly, Nordkart's convention says a price change should also close the old
`price_history` row and open a new one, in the same transaction — that's
Exercise 5, once you've met transactions.

### 9.3.2 WHERE from a subquery

Merchandising wants to discontinue dead stock: active products introduced
before 2025 that have **never sold a single unit**. That's the anti-join
pattern from Module 4, now steering an UPDATE. Dry-run first:

```sql
SELECT COUNT(*) AS will_be_discontinued
FROM products p
WHERE p.is_active = 1
  AND p.introduced_at < '2025-01-01'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id);
```

```text
╭──────────────────────╮
│ will_be_discontinued │
╞══════════════════════╡
│                   30 │
╰──────────────────────╯
```

Thirty rows — matches expectations (the catalog has 41 never-sold products, but
some are recent or already inactive). Execute, and confirm the count with
`changes()`, which reports how many rows the last statement modified:

```sql
UPDATE products
SET is_active = 0
WHERE is_active = 1
  AND introduced_at < '2025-01-01'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = products.product_id);

SELECT changes() AS rows_updated;
```

```text
╭──────────────╮
│ rows_updated │
╞══════════════╡
│           30 │
╰──────────────╯
```

Dry-run said 30, `changes()` says 30. When those two numbers disagree,
something changed under you — stop and investigate.

> **PostgreSQL note:** there's no `changes()` function; the rows-affected count
> comes back in the command tag (`UPDATE 30` in psql) or via your driver
> (`cursor.rowcount`, `GET DIAGNOSTICS` in PL/pgSQL).

### 9.3.3 UPDATE ... FROM — update one table from another

Summer clearance: finance sends per-category markdowns for winter gear. Put
the markdowns in a table, then let `UPDATE ... FROM` (SQLite 3.33+, and
PostgreSQL since forever) join it to `products`:

```sql
CREATE TABLE summer_sale (
    category_id  INTEGER PRIMARY KEY,
    discount_pct REAL NOT NULL
);

INSERT INTO summer_sale VALUES (15, 20), (16, 25), (17, 15);

UPDATE products
SET unit_price = ROUND(unit_price * (1 - summer_sale.discount_pct / 100.0), 2)
FROM summer_sale
WHERE products.category_id = summer_sale.category_id
  AND products.is_active = 1;

SELECT changes() AS products_repriced;
```

```text
╭───────────────────╮
│ products_repriced │
╞═══════════════════╡
│                41 │
╰───────────────────╯
```

Only rows with a match in `summer_sale` are touched — the join condition in
`WHERE` doubles as the row filter. Spot-check Avalanche Safety (15% off),
using `price_history`'s current row as the "before" record:

```sql
SELECT p.sku, p.name, ph.price AS price_before, p.unit_price AS sale_price
FROM products p
JOIN price_history ph
  ON ph.product_id = p.product_id AND ph.valid_to IS NULL
WHERE p.category_id = 17 AND p.is_active = 1
ORDER BY p.product_id
LIMIT 4;
```

```text
╭────────────┬────────────────────────┬──────────────┬────────────╮
│    sku     │          name          │ price_before │ sale_price │
╞════════════╪════════════════════════╪══════════════╪════════════╡
│ NK-17-0003 │ Guard Avalanche Beacon │       602.95 │     512.51 │
│ NK-17-0084 │ Probe Probe 240cm      │       102.02 │      86.72 │
│ NK-17-0116 │ Probe Snow Shovel      │       744.12 │      632.5 │
│ NK-17-0121 │ Pulse Probe 240cm      │       310.96 │     264.32 │
╰────────────┴────────────────────────┴──────────────┴────────────╯
```

> **PostgreSQL note:** same `UPDATE ... FROM ... WHERE` shape. MySQL is the
> odd one out with `UPDATE products JOIN summer_sale ON ... SET ...`.

## 9.4 DELETE

### 9.4.1 DELETE with a subquery

Legal asks: purge clickstream events older than 2024 for customers who opted
out of marketing. Dry-run, then delete:

```sql
SELECT COUNT(*) AS events_to_purge
FROM events
WHERE occurred_at < '2024-01-01'
  AND customer_id IN (SELECT customer_id FROM customers WHERE marketing_opt_in = 0);
```

```text
╭─────────────────╮
│ events_to_purge │
╞═════════════════╡
│             853 │
╰─────────────────╯
```

```sql
DELETE FROM events
WHERE occurred_at < '2024-01-01'
  AND customer_id IN (SELECT customer_id FROM customers WHERE marketing_opt_in = 0);

SELECT changes() AS rows_deleted,
       (SELECT COUNT(*) FROM events) AS events_remaining;
```

```text
╭──────────────┬──────────────────╮
│ rows_deleted │ events_remaining │
╞══════════════╪══════════════════╡
│          853 │            15511 │
╰──────────────┴──────────────────╯
```

> **PostgreSQL note:** for join-shaped deletes PostgreSQL also offers
> `DELETE FROM events USING customers WHERE ...` — the DELETE counterpart of
> `UPDATE ... FROM`.

### 9.4.2 DELETE without WHERE — the TRUNCATE-equivalent

`DELETE FROM t;` with no WHERE removes **every row**. That's occasionally
exactly what you want — clearing a staging or scratch table before a reload:

```sql
DELETE FROM load_log;

SELECT changes() AS rows_deleted,
       (SELECT COUNT(*) FROM load_log) AS rows_remaining;
```

```text
╭──────────────┬────────────────╮
│ rows_deleted │ rows_remaining │
╞══════════════╪════════════════╡
│            1 │              0 │
╰──────────────┴────────────────╯
```

SQLite has no `TRUNCATE` statement; an unqualified `DELETE` uses an internal
fast path (the "truncate optimization") instead of visiting rows one by one.

> **PostgreSQL note:** `TRUNCATE TABLE t` exists and is much faster than
> `DELETE` on large tables — it deallocates the storage rather than deleting
> rows, can reset identity sequences (`RESTART IDENTITY`), and can cascade to
> dependent tables. Prefer it for full wipes of big tables.

### 9.4.3 Soft delete — usually the better tool

Notice what we did **not** do in 9.3.2: we didn't `DELETE` the dead products,
we set `is_active = 0`. That's the *soft-delete* pattern, and for business
entities it's almost always right:

- Hard deletes break history: order 1234 references product 87; delete product
  87 and the order can no longer be explained (with foreign keys enforced, the
  delete is rejected anyway).
- Soft deletes are reversible — a "discontinued" product can come back (you'll
  see one resurrected by a catalog feed in 9.8).
- Queries just add `WHERE is_active = 1`, typically hidden behind a view
  (Module 8) such as `CREATE VIEW active_products AS ...`.

Reserve hard `DELETE` for data that is genuinely disposable (staging rows,
expired sessions) or that you're legally required to erase — like the
clickstream purge above.

## 9.5 Transactions

### 9.5.1 The problem: multi-statement changes

Order 5992 (delivered, 85.87 of item revenue) comes back. Processing the
return means **two** writes that must both happen or both not happen: flip the
order's status, and record the refund payment. If only the first lands, revenue
reports and payment reconciliation silently disagree — the classic
half-applied change.

A transaction makes the pair atomic. `BEGIN` opens it, `COMMIT` makes all of it
permanent at once:

```sql
BEGIN;

UPDATE orders
SET status = 'returned'
WHERE order_id = 5992 AND status = 'delivered';

INSERT INTO payments (order_id, amount, method, status, paid_at)
VALUES (5992, -85.87, 'refund', 'captured', '2026-07-15 09:14:00');

COMMIT;

SELECT o.status, p.amount, p.method, p.paid_at
FROM orders o
JOIN payments p USING (order_id)
WHERE o.order_id = 5992
ORDER BY p.paid_at;
```

```text
╭──────────┬────────┬────────┬─────────────────────╮
│  status  │ amount │ method │       paid_at       │
╞══════════╪════════╪════════╪═════════════════════╡
│ returned │  85.87 │ card   │ 2026-06-20 18:44:03 │
│ returned │ -85.87 │ refund │ 2026-07-15 09:14:00 │
╰──────────┴────────┴────────┴─────────────────────╯
```

Both rows show `returned`; the original capture and the new refund sit side by
side. (Refunds are negative amounts — Nordkart convention from DATASET.md.)

### 9.5.2 Atomicity when things go wrong

Now the same flow for order 5984, but the operator fat-fingers the payment
method as `cash` — which the CHECK constraint on `payments.method` rejects.
Watch closely what happens inside the transaction:

```sql
-- BAD: the INSERT violates payments' CHECK constraint mid-transaction;
-- the UPDATE before it would linger half-applied until we ROLLBACK
BEGIN;

UPDATE orders
SET status = 'returned'
WHERE order_id = 5984 AND status = 'delivered';

INSERT INTO payments (order_id, amount, method, status, paid_at)
VALUES (5984, -235.43, 'cash', 'captured', '2026-07-15 09:20:00');

SELECT status AS status_inside_txn FROM orders WHERE order_id = 5984;

ROLLBACK;

SELECT status AS status_after_rollback FROM orders WHERE order_id = 5984;
```

```text
Error near line 9: CHECK constraint failed: method IN
                   ('card', 'paypal', 'klarna', 'bank_transfer', 'refund')
╭───────────────────╮
│ status_inside_txn │
╞═══════════════════╡
│ returned          │
╰───────────────────╯
╭───────────────────────╮
│ status_after_rollback │
╞═══════════════════════╡
│ delivered             │
╰───────────────────────╯
```

Read that output carefully — it's the whole lesson:

1. The INSERT failed. In SQLite an error **aborts the statement, not the
   transaction**: the transaction stays open, with the UPDATE still applied
   inside it (`status_inside_txn` is `returned`).
2. Nothing automatically cleans up. It's the *application's* job to see the
   error and issue `ROLLBACK`, which undoes everything back to `BEGIN` —
   afterwards the order is `delivered` again, and no refund row exists.

In application code the pattern is always: `BEGIN` → statements → on any
error, `ROLLBACK` and re-raise; only `COMMIT` when every statement succeeded.

> **PostgreSQL note:** PostgreSQL is stricter — any error puts the whole
> transaction in an aborted state (`current transaction is aborted, commands
> ignored until end of transaction block`). Every later statement fails, and
> a `COMMIT` on an aborted transaction actually performs a rollback. Same
> discipline, enforced harder. (Savepoints — `SAVEPOINT` / `ROLLBACK TO` —
> exist in both engines for partial undo; we won't need them here.)

### 9.5.3 ACID, practically

The four letters, in terms of what you just saw:

- **Atomicity** — all statements between `BEGIN` and `COMMIT` land together or
  not at all. That's the 5984 demo: `ROLLBACK` erased the half-done return.
- **Consistency** — constraints hold before and after each transaction. The
  CHECK on `payments.method` refused to let inconsistent data in; constraints
  plus transactions mean the database moves between valid states only.
- **Isolation** — concurrent transactions don't see each other's unfinished
  work. Our `status_inside_txn` SELECT saw `returned` because it ran *inside*
  the transaction; another connection at that moment would still have seen
  `delivered`. More in 9.6.
- **Durability** — once `COMMIT` returns, the change survives a crash or power
  cut. SQLite implements this with its journal (or WAL) and fsync; that's
  *why* commits aren't free.

One more practical fact: without `BEGIN`, SQLite runs in **autocommit** mode —
every statement is its own tiny transaction, committed the instant it
finishes. That's why a lone `UPDATE` is instantly permanent, and why
multi-statement changes need an explicit `BEGIN`.

## 9.6 Isolation — who sees what, when

### 9.6.1 SQLite: one writer at a time

SQLite's model is simple: **any number of readers, at most one writer**. A
second connection that tries to write while a transaction holds the write lock
gets `SQLITE_BUSY` and must retry. In the default rollback-journal mode, a
writer also blocks readers during commit. Check your mode:

```sql
PRAGMA journal_mode;
```

```text
╭──────────────╮
│ journal_mode │
╞══════════════╡
│ delete       │
╰──────────────╯
```

Production SQLite deployments almost always switch to **WAL** (write-ahead
logging: `PRAGMA journal_mode = WAL;`) — readers then work from a stable
snapshot while the single writer appends to a log, so readers and the writer
never block each other. Still one writer at a time, though; SQLite is a
brilliant embedded database, not a concurrency engine.

### 9.6.2 PostgreSQL: isolation levels and the lost update

Client-server databases juggle many concurrent writers, and the SQL standard
defines *isolation levels* that trade strictness for throughput. A concrete
story — two support agents, same moment, same customer credit balance of 100:

1. Agent A reads balance: 100. Plans to add a 20 goodwill credit → 120.
2. Agent B reads balance: 100. Plans to deduct a 30 fee → 70.
3. A writes 120. B writes 70. **A's credit has vanished** — a *lost update*.
   The final balance should have been 90.

How each PostgreSQL level treats this read-modify-write:

- **READ COMMITTED** (the default): each statement sees the latest committed
  data, but nothing stops the interleaving above — the lost update happens.
  Fix it yourself: make the write relative in one atomic statement
  (`UPDATE ... SET balance = balance + 20`) or lock the row first
  (`SELECT ... FOR UPDATE`).
- **REPEATABLE READ**: the transaction works from a snapshot taken at its
  start; if B tries to overwrite a row A changed since that snapshot, B's
  update fails with a serialization error and must retry. Lost update caught.
- **SERIALIZABLE**: the strictest — the outcome is guaranteed equivalent to
  *some* one-at-a-time execution of the transactions; anomalies beyond simple
  lost updates (write skew) are also detected. The price: transactions can be
  aborted and must be written to retry.

The engineering takeaway is level-independent: **never read a value into your
app, compute, and write it back** when a single relative UPDATE can do the
same job atomically. That habit makes the lost update impossible at any
isolation level — in SQLite, PostgreSQL, or anything else.

## 9.7 UPSERT — insert-or-update in one statement

The daily reality of a data engineer: a feed arrives, some rows are new, some
are updates to rows you already have. Plain INSERT can't cope:

```sql
-- BAD: this SKU already exists — a plain INSERT refuses to load the update
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-21-0006', 'Tide Dry Bag 10L', 21, 36, 25.90, 9.86, 1, '2026-07-15');
```

```text
Error near line 2: UNIQUE constraint failed: products.sku
```

`ON CONFLICT` tells the INSERT what to do instead of failing. The **conflict
target** must be a set of columns with a UNIQUE constraint or primary key —
here `sku`, the natural business key. Option one, ignore the row:

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-21-0006', 'Tide Dry Bag 10L', 21, 36, 25.90, 9.86, 1, '2026-07-15')
ON CONFLICT (sku) DO NOTHING;

SELECT changes() AS rows_written;
```

```text
╭──────────────╮
│ rows_written │
╞══════════════╡
│            0 │
╰──────────────╯
```

Zero rows written, no error. `DO NOTHING` suits append-only feeds where a
re-sent row can be safely skipped. For a price feed we want option two,
`DO UPDATE` — and its special `excluded` pseudo-table, which holds *the row
you tried to insert*:

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
VALUES
    ('NK-21-0006', 'Tide Dry Bag 10L', 21, 36, 25.90, 9.86, 1, '2026-07-15')
ON CONFLICT (sku) DO UPDATE SET
    unit_price = excluded.unit_price,
    is_active  = excluded.is_active
RETURNING product_id, sku, unit_price, introduced_at;
```

```text
╭────────────┬────────────┬────────────┬─────────────────────╮
│ product_id │    sku     │ unit_price │    introduced_at    │
╞════════════╪════════════╪════════════╪═════════════════════╡
│          6 │ NK-21-0006 │       25.9 │ 2026-04-11 13:37:42 │
╰────────────┴────────────┴────────────┴─────────────────────╯
```

Dissect the result: the price is the feed's 25.90, but `introduced_at` still
shows the product's original 2026-04-11 — because the `DO UPDATE SET` listed
only the columns the feed is allowed to change. That column list is a policy
decision: a price feed should never be able to rewrite when a product was
introduced. `excluded.column` means "the incoming value"; a bare `column`
inside the SET means the existing row's value.

> **PostgreSQL note:** the syntax is identical — SQLite copied PostgreSQL's
> `ON CONFLICT` clause wholesale, including `excluded`. PostgreSQL 15+ also has
> the standard's `MERGE` statement (multi-branch WHEN MATCHED / NOT MATCHED
> logic); SQLite doesn't. For plain sync jobs, `ON CONFLICT` is what you'll
> write in both engines.

## 9.8 The professional load pattern: staging → validate → upsert

Now the real thing — the job you will write dozens of times in your career.
Every morning, suppliers send Nordkart a catalog feed CSV. The naive move is
to load it straight into `products`. The professional pattern inserts two
safety layers:

1. **Staging table** — load the raw file into a table that nothing else reads.
   If the file is garbage, production tables never saw it.
2. **Assertion queries** — prove the batch is sane *before* it touches the
   target.
3. **Upsert inside a transaction** — apply the whole batch atomically, in a
   form that's safe to re-run.

Create today's feed file (in real life it lands via SFTP; ours is a heredoc so
the module is reproducible):

```bash
cat > catalog_feed_2026-07-15.csv <<'CSV'
sku,name,category_id,supplier_id,unit_price,unit_cost,is_active
NK-08-0002,Wall Harness,8,9,89.00,48.26,1
NK-17-0003,Guard Avalanche Beacon,17,23,559.00,265.21,1
NK-21-0006,Tide Dry Bag 10L,21,36,26.90,9.86,1
NK-24-0001,Merino Base Layer Top,24,29,99.00,51.74,1
NK-19-0354,Fjord Touring Kayak,19,41,1249.00,610.00,1
NK-25-0355,Polar Mittens,25,41,39.90,14.50,1
CSV
```

Four updates (including `NK-24-0001`, a product we know is currently
discontinued — the feed reactivates it) and two brand-new products. Stage it:

```sql
CREATE TABLE stg_catalog_feed (
    sku         TEXT,
    name        TEXT,
    category_id INTEGER,
    supplier_id INTEGER,
    unit_price  REAL,
    unit_cost   REAL,
    is_active   INTEGER
);

SELECT COUNT(*) AS staged_rows FROM stg_catalog_feed;
```

```text
╭─────────────╮
│ staged_rows │
╞═════════════╡
│           0 │
╰─────────────╯
```

The staging table is loose on purpose — no PK, no NOT NULL. Its job is to
accept whatever the file contains so we can *inspect* it; the constraints live
on the target. Load the CSV with the CLI's `.import` (note the `DELETE`
first: staging is always cleared before a load, so re-importing can't stack
batches):

```bash
sqlite3 -box scratch.db \
  "DELETE FROM stg_catalog_feed;" \
  ".import --csv --skip 1 catalog_feed_2026-07-15.csv stg_catalog_feed" \
  "SELECT COUNT(*) AS staged_rows FROM stg_catalog_feed;"
```

```text
╭─────────────╮
│ staged_rows │
╞═════════════╡
│           6 │
╰─────────────╯
```

> **PostgreSQL note:** the equivalent bulk loader is `COPY table FROM file`
> (server-side) or psql's `\copy` (client-side). Same architecture: land the
> file in staging, validate, then move it.

Now the assertion queries. Each one counts rows violating a rule; a healthy
batch is a column of zeros:

```sql
SELECT 'sku missing' AS problem, COUNT(*) AS n
FROM stg_catalog_feed WHERE sku IS NULL OR sku = ''
UNION ALL
SELECT 'duplicate sku in feed', COUNT(*)
FROM (SELECT sku FROM stg_catalog_feed GROUP BY sku HAVING COUNT(*) > 1)
UNION ALL
SELECT 'non-positive price', COUNT(*)
FROM stg_catalog_feed WHERE unit_price IS NULL OR unit_price <= 0
UNION ALL
SELECT 'price below cost', COUNT(*)
FROM stg_catalog_feed WHERE unit_price < unit_cost
UNION ALL
SELECT 'unknown category_id', COUNT(*)
FROM stg_catalog_feed WHERE category_id NOT IN (SELECT category_id FROM categories)
UNION ALL
SELECT 'unknown supplier_id', COUNT(*)
FROM stg_catalog_feed WHERE supplier_id NOT IN (SELECT supplier_id FROM suppliers);
```

```text
╭───────────────────────┬───╮
│        problem        │ n │
╞═══════════════════════╪═══╡
│ sku missing           │ 0 │
│ duplicate sku in feed │ 0 │
│ non-positive price    │ 0 │
│ price below cost      │ 0 │
│ unknown category_id   │ 0 │
│ unknown supplier_id   │ 0 │
╰───────────────────────┴───╯
```

All zeros — green light. In a scripted job you'd wrap this with
`WHERE n > 0` and abort the load if it returns any rows (Module 12 turns this
into a general SQL-testing technique).

One SQLite parser quirk before the main event. `INSERT ... SELECT` followed by
`ON CONFLICT` is ambiguous to SQLite's parser (it can't tell whether `ON`
starts a join clause), so it demands the SELECT end with a WHERE:

```sql
-- BAD: SQLite rejects INSERT ... SELECT ... ON CONFLICT without a WHERE clause
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
SELECT sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, '2026-07-15'
FROM stg_catalog_feed
ON CONFLICT (sku) DO UPDATE SET unit_price = excluded.unit_price;
```

```text
Parse error near line 2: near "DO": syntax error
  26-07-15' FROM stg_catalog_feed ON CONFLICT (sku) DO UPDATE SET unit_price = e
                                      error here ---^
```

The idiomatic fix is a vacuous `WHERE true`. (PostgreSQL doesn't need it.)
Here is the load itself — upsert plus an audit-log row, one transaction:

```sql
BEGIN;

INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
SELECT sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, '2026-07-15'
FROM stg_catalog_feed
WHERE true
ON CONFLICT (sku) DO UPDATE SET
    name       = excluded.name,
    unit_price = excluded.unit_price,
    unit_cost  = excluded.unit_cost,
    is_active  = excluded.is_active;

INSERT INTO load_log (source, note)
VALUES ('catalog_feed',
        (SELECT COUNT(*) FROM stg_catalog_feed) || ' rows from catalog_feed_2026-07-15.csv');

COMMIT;

SELECT COUNT(*) AS n_products,
       SUM(is_active) AS n_active,
       ROUND(SUM(unit_price), 2) AS price_checksum
FROM products;
```

```text
╭────────────┬──────────┬────────────────╮
│ n_products │ n_active │ price_checksum │
╞════════════╪══════════╪════════════════╡
│        355 │      300 │       70906.01 │
╰────────────┴──────────┴────────────────╯
```

Now the property that makes this pattern professional: **run it again**. A
retried cron job, a duplicate file delivery, an operator double-click — reruns
happen, and a good load shrugs them off:

```sql
INSERT INTO products
    (sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)
SELECT sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, '2026-07-15'
FROM stg_catalog_feed
WHERE true
ON CONFLICT (sku) DO UPDATE SET
    name       = excluded.name,
    unit_price = excluded.unit_price,
    unit_cost  = excluded.unit_cost,
    is_active  = excluded.is_active;

SELECT COUNT(*) AS n_products,
       SUM(is_active) AS n_active,
       ROUND(SUM(unit_price), 2) AS price_checksum
FROM products;
```

```text
╭────────────┬──────────┬────────────────╮
│ n_products │ n_active │ price_checksum │
╞════════════╪══════════╪════════════════╡
│        355 │      300 │       70906.01 │
╰────────────┴──────────┴────────────────╯
```

Identical count, identical checksum: the load is **idempotent** — applying it
twice equals applying it once. The upserted rows simply get set to values they
already have. (The `load_log` insert is deliberately *not* idempotent — an
audit log should record every run — which is why it lives with the upsert
inside the transaction but wasn't repeated here.)

And the storyline check — the discontinued base layer really did come back,
and the kayak is new:

```sql
SELECT product_id, sku, name, unit_price, is_active, introduced_at
FROM products
WHERE sku IN ('NK-24-0001', 'NK-19-0354', 'NK-21-0006')
ORDER BY product_id;
```

```text
╭────────────┬────────────┬───────────────────────┬────────────┬───────────┬─────────────────────╮
│ product_id │    sku     │         name          │ unit_price │ is_active │    introduced_at    │
╞════════════╪════════════╪═══════════════════════╪════════════╪═══════════╪═════════════════════╡
│          1 │ NK-24-0001 │ Merino Base Layer Top │       99.0 │         1 │ 2022-09-04 09:36:44 │
│          6 │ NK-21-0006 │ Tide Dry Bag 10L      │       26.9 │         1 │ 2026-04-11 13:37:42 │
│        354 │ NK-19-0354 │ Fjord Touring Kayak   │     1249.0 │         1 │ 2026-07-15          │
╰────────────┴────────────┴───────────────────────┴────────────┴───────────┴─────────────────────╯
```

`NK-24-0001` kept its original `product_id` (1) and its 2022 `introduced_at`
— because for existing rows only the `DO UPDATE SET` columns changed. Soft
delete plus upsert gave us resurrection for free.

## 9.9 Safe destructive operations — the checklist

Everything above condenses into a discipline. Before any UPDATE or DELETE that
matters:

1. **SELECT first.** Same WHERE clause, eyeball the rows.
2. **Dry-run count.** `SELECT COUNT(*)` with the same WHERE; remember the
   number.
3. **Wrap in a transaction.** `BEGIN` → statement → compare `changes()` to the
   dry-run count → inspect → `COMMIT` or `ROLLBACK`. A transaction turns "oh
   no" into "rollback".
4. **Canary run.** For big changes, hit a handful of rows first. Neither
   SQLite (as normally compiled) nor PostgreSQL supports `UPDATE ... LIMIT`,
   so the portable canary is a primary-key subquery with a LIMIT.

Here's the full ritual: merchandising proposes rounding every active price to
a `.90` ending ("charm pricing") — we canary five products inside a
transaction, inspect, and in this case decide to back out:

```sql
BEGIN;

UPDATE products
SET unit_price = CAST(unit_price AS INTEGER) + 0.90
WHERE product_id IN (
    SELECT product_id
    FROM products
    WHERE is_active = 1
    ORDER BY product_id
    LIMIT 5
);

SELECT changes() AS canary_rows;

SELECT product_id, sku, unit_price
FROM products
WHERE is_active = 1
ORDER BY product_id
LIMIT 5;

ROLLBACK;

SELECT product_id, sku, unit_price
FROM products
WHERE is_active = 1
ORDER BY product_id
LIMIT 5;
```

```text
╭─────────────╮
│ canary_rows │
╞═════════════╡
│           5 │
╰─────────────╯
╭────────────┬────────────┬────────────╮
│ product_id │    sku     │ unit_price │
╞════════════╪════════════╪════════════╡
│          1 │ NK-24-0001 │       99.9 │
│          2 │ NK-08-0002 │       89.9 │
│          3 │ NK-17-0003 │      559.9 │
│          4 │ NK-11-0004 │      267.9 │
│          5 │ NK-12-0005 │       92.9 │
╰────────────┴────────────┴────────────╯
╭────────────┬────────────┬────────────╮
│ product_id │    sku     │ unit_price │
╞════════════╪════════════╪════════════╡
│          1 │ NK-24-0001 │       99.0 │
│          2 │ NK-08-0002 │       89.0 │
│          3 │ NK-17-0003 │      559.0 │
│          4 │ NK-11-0004 │     267.64 │
│          5 │ NK-12-0005 │      92.68 │
╰────────────┴────────────┴────────────╯
```

Five rows repriced, inspected inside the transaction, then `ROLLBACK` restored
every original price. Total cost of the experiment: zero.

## Pitfalls

### Pitfall 1: UPDATE without WHERE

The most expensive typo in SQL. You meant to reprice one dry bag; you sent
this:

```sql
-- BAD: no WHERE clause — this reprices the ENTIRE catalog
BEGIN;

UPDATE products SET unit_price = 9.99;

SELECT changes()        AS rows_hit,
       MIN(unit_price)  AS min_price,
       MAX(unit_price)  AS max_price
FROM products;

ROLLBACK;

SELECT MIN(unit_price) AS min_price, MAX(unit_price) AS max_price
FROM products;
```

```text
╭──────────┬───────────┬───────────╮
│ rows_hit │ min_price │ max_price │
╞══════════╪═══════════╪═══════════╡
│      355 │      9.99 │      9.99 │
╰──────────┴───────────┴───────────╯
╭───────────┬───────────╮
│ min_price │ max_price │
╞═══════════╪═══════════╡
│      8.18 │    1249.0 │
╰───────────┴───────────╯
```

Every one of the 355 products — the whole catalog, kayaks to socks — now costs
9.99. On a production database in autocommit mode that's instantly
permanent, and you're restoring from backup while orders flow in at wrong
prices. Here it cost nothing, for exactly one reason: **the `BEGIN` came
first**, so `ROLLBACK` could unwind it. That's the habit. The `SELECT`-first
discipline from 9.9 would have caught it too — "355 rows will change" is a
loud alarm when you expected 1.

`DELETE` has the same failure mode with higher stakes:

```sql
-- BAD: meant to purge one customer's events; the WHERE never got typed
BEGIN;

DELETE FROM events;

SELECT (SELECT COUNT(*) FROM events) AS events_left;

ROLLBACK;

SELECT COUNT(*) AS events_after_rollback FROM events;
```

```text
╭─────────────╮
│ events_left │
╞═════════════╡
│           0 │
╰─────────────╯
╭───────────────────────╮
│ events_after_rollback │
╞═══════════════════════╡
│                 15511 │
╰───────────────────────╯
```

An entire table, gone between two keystrokes — and restored only because of
the transaction. Many CLI tools can refuse unqualified UPDATE/DELETE
(psql habits, `--safe-updates` in MySQL); use those guards where they exist,
but rely on the transaction.

### Pitfall 2: a scalar-subquery UPDATE that returns NULL wipes data

Support sends a small table of corrected phone numbers. The "obvious" UPDATE
sets every customer's phone from a correlated subquery:

```sql
CREATE TABLE phone_corrections (
    customer_id INTEGER PRIMARY KEY,
    new_phone   TEXT NOT NULL
);

INSERT INTO phone_corrections VALUES
    (3,  '+47 40112233'),
    (7,  '+46 70 555 1212'),
    (12, '+45 20 44 55 66');

SELECT COUNT(*) AS corrections FROM phone_corrections;
```

```text
╭─────────────╮
│ corrections │
╞═════════════╡
│           3 │
╰─────────────╯
```

```sql
-- BAD: the subquery returns NULL for the 797 customers NOT in
-- phone_corrections — and the UPDATE happily writes those NULLs
BEGIN;

SELECT COUNT(*) AS phones_before FROM customers WHERE phone IS NOT NULL;

UPDATE customers
SET phone = (
    SELECT new_phone
    FROM phone_corrections pc
    WHERE pc.customer_id = customers.customer_id
);

SELECT COUNT(*) AS phones_after FROM customers WHERE phone IS NOT NULL;

ROLLBACK;
```

```text
╭───────────────╮
│ phones_before │
╞═══════════════╡
│           569 │
╰───────────────╯
╭──────────────╮
│ phones_after │
╞══════════════╡
│            3 │
╰──────────────╯
```

From 569 phone numbers to 3. There's no error, no warning — a scalar subquery
that matches nothing yields NULL (Module 5), and `SET phone = NULL` is a
perfectly legal assignment. The UPDATE had no WHERE, so it visited all 800
customers and wrote NULL into the 797 without a correction — silently erasing
all 567 real phone numbers outside the corrections list.

Two correct forms. Either keep the subquery but restrict the UPDATE to rows
that have a correction (`WHERE EXISTS (...)`) — or better, use
`UPDATE ... FROM`, where the join naturally touches only matching rows:

```sql
UPDATE customers
SET phone = pc.new_phone
FROM phone_corrections pc
WHERE pc.customer_id = customers.customer_id;

SELECT changes() AS rows_updated,
       (SELECT COUNT(*) FROM customers WHERE phone IS NOT NULL) AS phones_now;
```

```text
╭──────────────┬────────────╮
│ rows_updated │ phones_now │
╞══════════════╪════════════╡
│            3 │        570 │
╰──────────────┴────────────╯
```

Three rows touched, phone count up by one (customer 7 previously had none),
everyone else untouched.

### Pitfall 3: the non-idempotent load, run twice

A plain `INSERT ... SELECT` backfill works perfectly — once. Build a June
daily-revenue table (canonical gross revenue: item revenue of non-cancelled
orders):

```sql
CREATE TABLE daily_revenue (
    day           TEXT,
    gross_revenue REAL
);

INSERT INTO daily_revenue (day, gross_revenue)
SELECT date(o.ordered_at),
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-06-01' AND o.ordered_at < '2026-07-01'
GROUP BY date(o.ordered_at);

SELECT COUNT(*) AS days_loaded, ROUND(SUM(gross_revenue), 2) AS june_gross
FROM daily_revenue;
```

```text
╭─────────────┬────────────╮
│ days_loaded │ june_gross │
╞═════════════╪════════════╡
│          30 │  288614.97 │
╰─────────────┴────────────╯
```

That night the scheduler times out and retries the job:

```sql
-- BAD: identical load, run a second time — nothing stops it
INSERT INTO daily_revenue (day, gross_revenue)
SELECT date(o.ordered_at),
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-06-01' AND o.ordered_at < '2026-07-01'
GROUP BY date(o.ordered_at);

SELECT COUNT(*) AS rows_now, ROUND(SUM(gross_revenue), 2) AS june_gross_now
FROM daily_revenue;
```

```text
╭──────────┬────────────────╮
│ rows_now │ june_gross_now │
╞══════════╪════════════════╡
│       60 │      577229.94 │
╰──────────┴────────────────╯
```

Every day now exists twice and June's revenue doubled. No constraint objected
because `daily_revenue` has no key — and dashboards don't validate, they
display. This bug ships to a Monday-morning meeting.

The fix: make the load **delete-then-insert over the same window, in one
transaction** (or give the table a PK and upsert — Exercise 7). Either way,
running it N times equals running it once:

```sql
BEGIN;

DELETE FROM daily_revenue
WHERE day >= '2026-06-01' AND day < '2026-07-01';

INSERT INTO daily_revenue (day, gross_revenue)
SELECT date(o.ordered_at),
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2)
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.status <> 'cancelled'
  AND o.ordered_at >= '2026-06-01' AND o.ordered_at < '2026-07-01'
GROUP BY date(o.ordered_at);

COMMIT;

SELECT COUNT(*) AS rows_now, ROUND(SUM(gross_revenue), 2) AS june_gross
FROM daily_revenue;
```

```text
╭──────────┬────────────╮
│ rows_now │ june_gross │
╞══════════╪════════════╡
│       30 │  288614.97 │
╰──────────┴────────────╯
```

Back to 30 rows and the true number — and this version can be retried forever.
The transaction matters: if the job dies between DELETE and INSERT, the
rollback leaves yesterday's data in place rather than an empty table.

### Pitfall 4: forgetting COMMIT

Interactive session, end of day: you `BEGIN`, run your fix, verify it looks
right... and close the laptop.

```bash
sqlite3 -box scratch.db \
  "BEGIN;
   UPDATE products SET unit_price = 199.00 WHERE product_id = 2;
   SELECT unit_price AS price_inside_txn FROM products WHERE product_id = 2;"
```

```text
╭──────────────────╮
│ price_inside_txn │
╞══════════════════╡
│            199.0 │
╰──────────────────╯
```

Looks committed, right? It isn't. That `sqlite3` process exited with the
transaction still open, and SQLite rolls back any open transaction when the
connection closes. Next morning:

```bash
sqlite3 -box scratch.db \
  "SELECT unit_price AS price_next_morning FROM products WHERE product_id = 2;"
```

```text
╭────────────────────╮
│ price_next_morning │
╞════════════════════╡
│               89.0 │
╰────────────────────╯
```

The update evaporated — it's back to the 89.00 the catalog feed set. Your
"fix" was never durable because durability is a property of **COMMIT**, not of
seeing your own changes on screen. The mirror-image failure is nastier in
client-server databases: a GUI session that holds a transaction open for hours
doesn't roll back — it sits on locks and blocks other writers. Either way the
rule is the same: **open transactions are finished promptly, with an explicit
COMMIT or ROLLBACK.**

## Exercises

Work on a fresh copy (`cp shop.db scratch.db`) so leftover state from the
module's demos doesn't shift your numbers. Solutions are in
`solutions/09-dml-and-transactions.md`.

**Warm-up**

1. Partnerships signed a new supplier: *Tundra Trading ApS*, Denmark, contact
   `hello@tundratrading.dk`. Insert it and produce its new `supplier_id` —
   without running a second statement.

2. Tundra's first two products arrive: *Tundra Down Booties* (SKU
   `NK-25-0351`, category 25, price 54.90, cost 22.10) and *Tundra Bivy Sack*
   (SKU `NK-02-0352`, category 2, price 189.00, cost 88.40). Both active,
   introduced `2026-07-15`. Load both in **one** statement (use the supplier id
   from exercise 1), then verify with a single SELECT.

3. Merchandising wants premium jackets cheaper: first report *how many* active
   products in category 23 (Jackets) cost more than 300 — then cut exactly
   those prices by 10% and prove the affected row count matches your dry-run.

**Core**

4. Order 5964 (delivered) came back. In one transaction: mark it `returned`
   and insert the refund payment — amount = **negative** canonical item
   revenue of the order, computed by the INSERT itself (`INSERT ... SELECT`),
   method `refund`, status `captured`, `paid_at` = `2026-07-16 10:00:00`. Use
   `RETURNING` to show the new `payment_id` and `amount`.

5. A price change done right: *Moss Approach Shoes* (`NK-11-0004`) goes to
   289.00 effective `2026-07-16 00:00:00`. In one transaction, keep
   `price_history` consistent with its SCD-2 shape: close the current history
   row (set its `valid_to`), insert the new current row (`valid_to` NULL), and
   update `products.unit_price`. Verify with a SELECT of the product's full
   price history.

6. A mini catalog feed arrives with three rows:
   `('NK-08-0002', 92.00)`, `('NK-12-0005', 84.90)` — price updates — and one
   new product: *Polaris Compass*, SKU `NK-13-0356`, category 13, supplier 38,
   price 44.90, cost 18.00, active, introduced `2026-07-16`. Write **one**
   upsert statement keyed on `sku` that applies all three (for existing
   products, only price may change; supply the current `name`/`category_id`/
   `supplier_id`/`unit_cost` values for the two updates: Wall Harness — 8, 9,
   48.26; Stride Ski Poles — 12, 40, 41.44). Run it twice and prove the second
   run changed nothing (product count + price checksum).

7. Write an **idempotent backfill**: a table
   `monthly_revenue (month TEXT PRIMARY KEY, gross_revenue REAL NOT NULL)`
   holding canonical gross revenue per month for 2025. The load must be safe
   to re-run (the PK is a hint). Run it twice and show the row count and total
   are stable.

8. Data retention: delete all rating-only reviews (`review_text IS NULL`) of
   discontinued products. Dry-run count first, wrap the delete in a
   transaction, and confirm `changes()` matches before committing.

**Challenge**

9. *Predict, then run.* This script is executed with
   `sqlite3 scratch.db < script.sql`:

   ```
   BEGIN;
   UPDATE products SET unit_price = 10.00 WHERE product_id = 5;
   INSERT INTO products (sku, name, category_id, supplier_id,
                         unit_price, unit_cost, is_active, introduced_at)
   VALUES ('NK-21-0006', 'Duplicate', 21, 36, 1, 1, 1, '2026-07-15');
   UPDATE products SET unit_price = 20.00 WHERE product_id = 5;
   COMMIT;
   ```

   The INSERT fails (duplicate SKU). What is product 5's `unit_price`
   afterwards — 92.68 (its original), 10.00, or 20.00? Write your answer and
   reasoning down, run it, then explain what the same script would leave
   behind in PostgreSQL.

10. *Predict, then run.* Two separate invocations (two connections):

    ```
    sqlite3 scratch.db "BEGIN; UPDATE products SET unit_price = 1.00 WHERE product_id = 6;"
    sqlite3 scratch.db "UPDATE products SET unit_price = 2.00 WHERE product_id = 6;"
    ```

    After both have run, what does a third connection see as product 6's
    price — 21.64 (original), 1.00, or 2.00? Predict, run, and state the two
    rules that explain it.

11. Build the full professional pipeline for a **daily orders export**. The
    file (create it with a heredoc):

    ```
    order_id,customer_id,address_id,status,shipping_cost,ordered_at
    6000,226,316,returned,0.0,2025-07-13 11:15:40
    6001,718,1004,pending,4.90,2026-07-15 08:12:00
    6002,202,282,paid,0.0,2026-07-15 09:47:00
    ```

    Order 6000 is a *restatement* (its status changed); 6001 and 6002 are new.
    Stage it with `.import`, validate with at least three assertion queries
    (unknown `customer_id`, unknown `address_id`, duplicate `order_id` in the
    feed, illegal `status` — pick three), then upsert into `orders` keyed on
    `order_id` (only `status` and `shipping_cost` may change on conflict)
    inside a transaction. Run the upsert twice and prove the orders table is
    stable at 6,002 rows.

## Key takeaways

- `INSERT INTO t (cols) VALUES (...), (...)` — always list columns; multi-row
  is one atomic statement. `INSERT ... SELECT` backfills from queries;
  `DEFAULT VALUES` makes an all-defaults row.
- `RETURNING` on INSERT/UPDATE/DELETE returns the affected rows — receipts,
  not guesses. `changes()` gives the affected-row count (PG: command tag).
- `UPDATE ... SET col = expr` reads pre-update values; `UPDATE ... FROM other
  WHERE join-cond` updates from another table *and only touches matching rows*.
- Scalar-subquery `SET` without a matching `WHERE EXISTS` writes NULL into
  every non-matching row. Prefer `UPDATE ... FROM`.
- `DELETE` without WHERE empties the table (PG: `TRUNCATE` is faster). For
  business entities prefer soft delete (`is_active = 0`).
- UPSERT: `INSERT ... ON CONFLICT (unique_cols) DO UPDATE SET col =
  excluded.col` / `DO NOTHING`. `excluded` = the incoming row. Update only the
  columns the feed owns. SQLite quirk: `INSERT ... SELECT ... WHERE true ON
  CONFLICT ...`.
- Transactions: `BEGIN` → statements → `COMMIT`, or `ROLLBACK` on any error.
  SQLite aborts the failing *statement* and leaves the transaction open; the
  app must roll back. PostgreSQL aborts the whole transaction. Without
  `BEGIN`, every statement autocommits.
- ACID: atomic all-or-nothing, constraints preserved, concurrent invisibility,
  durable at COMMIT — and only at COMMIT. Closing a connection mid-transaction
  rolls it back.
- Isolation: SQLite = many readers, one writer (WAL removes reader/writer
  blocking). PostgreSQL: READ COMMITTED permits lost updates in
  read-modify-write code; use relative updates (`SET x = x + d`),
  `SELECT ... FOR UPDATE`, or stricter levels.
- Loads: CSV → loose staging table (cleared first) → assertion queries → upsert
  in a transaction. **Idempotent** = running twice equals running once; get it
  via upsert or windowed delete-then-insert.
- Destructive-op ritual: SELECT first, dry-run COUNT, `BEGIN`, compare
  `changes()`, canary with `IN (SELECT pk ... LIMIT n)`, then COMMIT — or
  ROLLBACK and walk away unharmed.
