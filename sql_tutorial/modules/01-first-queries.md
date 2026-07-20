# Module 1 — First Queries

SQL is the one language every data engineer uses every day, on every stack: the pipelines you build, the warehouses you maintain, and the dashboards your stakeholders read all speak it. This module gets you from zero to writing real queries against a real operational database — Nordkart, an online outdoor-gear retailer — and, just as importantly, teaches you the habits that separate professional SQL from copy-pasted snippets: explicit column lists, deterministic ordering, and knowing exactly what the database does and does not guarantee.

## What you'll learn

- What a relational database is, and why it beats a spreadsheet for operational data
- Driving the `sqlite3` command-line client: `.open`, `.tables`, `.schema`, `.mode box`, `.headers`, `.quit`, running a `.sql` file
- Reading an unfamiliar schema methodically (a tour of Nordkart's 12 tables)
- `SELECT` with explicit column lists — and when `*` is acceptable
- Expressions in `SELECT`: arithmetic, the integer-division trap, string concatenation with `||`, `ROUND`
- Column aliases with `AS`, including quoted aliases
- `DISTINCT`, and what it really means on multiple columns
- `ORDER BY`: multiple keys, `ASC`/`DESC`, how NULLs sort, ordering by alias, expression, or position
- `LIMIT` and `OFFSET` for top-N queries and pagination — and the pitfalls of both
- SQL comments, statement structure, the semicolon, and keyword case

## Setup

### 1. Check that SQLite is installed

```bash
sqlite3 --version
```

```text
3.53.3 2026-06-26 20:14:12 d4c0e51e4aeb96955b99185ab9cde75c339e2c29c3f3f12428d364a10d78alt1 (64-bit)
```

Any version ≥ 3.39 works for this course (Module 4 uses `FULL JOIN`, added in 3.39); 3.53 is what the course was built against. If the command is missing, install it with your package manager (`apt install sqlite3`, `dnf install sqlite`, `pacman -S sqlite`, `brew install sqlite`).

### 2. Build the database (only if you don't have it yet)

All commands in this course run from the course root (the directory containing this `modules/` folder). The database `shop.db` ships with the course; if yours is missing, build it from the seed script. The command below is guarded so it does nothing when `shop.db` already exists:

```bash
[ -f shop.db ] || sqlite3 shop.db < data/seed.sql
```

`data/seed.sql` is a plain text file full of `CREATE TABLE` and `INSERT` statements — exactly the SQL you will be able to read yourself by Module 9. The database is fully reproducible: if you ever wreck it, delete it and rerun that command.

### 3. Read the map

Open **`DATASET.md`** in the course root and keep it within reach for the whole course. It documents every table, the deliberate data quirks (they are features, not bugs), and the **canonical metric definitions** — item revenue, gross/net revenue, AOV, active customer — that every module uses verbatim. We'll meet the first of those definitions in this module.

### 4. Configure the CLI

Start an interactive session and make the output readable:

```text
$ sqlite3 shop.db
SQLite version 3.53.3 2026-06-26 20:14:12
Enter ".help" for usage hints.
sqlite> .mode box
sqlite> .headers on
```

- `.mode box` draws results as boxed tables (the format used throughout this course). Other useful modes: `csv`, `json`, `list`.
- `.headers on` prints column names. Box mode shows headers anyway, but modes like `csv` and `list` need this switch.
- `.quit` (or Ctrl-D) exits.

Lines starting with a dot are **CLI commands**, not SQL — they are instructions to the `sqlite3` program itself, need no semicolon, and won't work in any other SQL tool. Everything else you type is SQL.

To make the settings permanent, put them in `~/.sqliterc`:

```text
.mode box
.headers on
```

You can also run a single query non-interactively — handy for scripting, and it's how this course was verified:

```bash
sqlite3 -box shop.db "SELECT 'it works' AS status;"
```

```text
╭──────────╮
│  status  │
╞══════════╡
│ it works │
╰──────────╯
```

From here on, every `sql` block in this module runs against `shop.db`, in order. Nothing in this module modifies the database — we are reading only.

## 1. What a relational database is

A **relational database** stores data as a set of **tables**. Each table has:

- a fixed set of named, typed **columns** (the *schema*), and
- any number of **rows**, each holding one value per column (possibly `NULL` — "unknown/absent", which gets its own section in Module 2).

Nordkart's `customers` table has columns like `customer_id`, `email`, `country`; each row is one customer. That sounds like a spreadsheet, but the differences are exactly what makes databases the backbone of every serious system:

| | Spreadsheet | Relational database |
|---|---|---|
| Structure | Anything can go in any cell | Schema enforced: every row has the same typed columns |
| Integrity | You hope nobody breaks it | Constraints: "email must be unique", "rating must be 1–5" — the engine *refuses* bad data |
| Relationships | Copy-paste, VLOOKUP | Rows reference rows via **keys**; one customer, many orders — stored once, linked by `customer_id` |
| Scale | Thousands of rows, then pain | Millions to billions of rows, with indexes to find things fast |
| Concurrency | "File is locked by another user" | Many readers and writers at once, safely (transactions, Module 9) |
| Interface | Clicking | A declarative language: you state *what* you want, the engine figures out *how* |

That last row is the deep one. SQL is **declarative**: you never write "loop over the rows and collect the ones where...". You describe the result set; the query planner picks the algorithm. This is why the same SQL keeps working as tables grow from a thousand rows to a billion — the planner just picks a different strategy (Module 10 shows you how to watch it do that).

**SQLite** is the engine we use to learn: the whole database is a single file (`shop.db`), there's no server to administer, and it implements modern SQL remarkably completely. Everything you learn transfers to client–server engines like PostgreSQL; where PostgreSQL differs, you'll see a callout like this:

> **PostgreSQL note:** PostgreSQL is a server you connect to (`psql mydb`) rather than a file you open, and its CLI uses backslash commands instead of dot commands: `\dt` ≈ `.tables`, `\d orders` ≈ `.schema orders`, `\q` ≈ `.quit`.

## 2. Touring an unfamiliar schema

The first thing a data engineer does with a new database is *look around*. Never query blind — thirty seconds of schema reading prevents hours of wrong answers.

List the tables:

```bash
sqlite3 shop.db ".tables"
```

```text
addresses     customers    order_items    payments         products    shipments
categories    events       orders         price_history    reviews     suppliers
```

Twelve tables. You can already guess the shape of the business: `customers` place `orders` made of `order_items` referencing `products`; orders are paid via `payments` and fulfilled via `shipments`; `products` live in `categories` and come from `suppliers`; `reviews` and clickstream `events` capture customer behavior; `addresses` and `price_history` support the rest.

Inspect one table's definition:

```bash
sqlite3 shop.db ".schema orders"
```

```text
CREATE TABLE orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
    address_id    INTEGER NOT NULL REFERENCES addresses(address_id),
    status        TEXT NOT NULL CHECK (status IN
                      ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned')),
    shipping_cost REAL NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    ordered_at    TEXT NOT NULL
);
```

Read it like a pro, top to bottom:

- `order_id INTEGER PRIMARY KEY` — the **primary key**: a value that uniquely identifies each row. Every well-designed table has one (Module 7 explains why).
- `REFERENCES customers(customer_id)` — a **foreign key**: this column holds primary-key values *of another table*. This is the "relational" in relational database; Module 4 is entirely about following these links.
- `CHECK (status IN (...))` — the engine enforces the six allowed statuses. The schema just told you the complete lifecycle of an order, including that cancelled and returned orders exist (which will matter for every revenue number you ever compute here).
- Dates are `TEXT` in ISO-8601 (`YYYY-MM-DD HH:MM:SS`) — SQLite's idiomatic choice; they compare and sort correctly as strings.

`.schema` with no argument dumps every table — do that once now, skim it, and cross-reference with `DATASET.md`, which also tells you row counts and the quirks you can't see from the DDL (e.g., *payments can be negative — refunds* and *125 customers have never ordered*).

### Running SQL from a file

Real work lives in files, not in a scrollback buffer. Save a query:

```bash
printf 'SELECT name, unit_price\nFROM products\nORDER BY unit_price DESC\nLIMIT 3;\n' > /tmp/top_products.sql
sqlite3 -box shop.db < /tmp/top_products.sql
```

```text
╭────────────────────────┬────────────╮
│          name          │ unit_price │
╞════════════════════════╪════════════╡
│ Drift Inflatable Kayak │    1004.85 │
│ Fjord Sit-on-Top Kayak │     934.86 │
│ Probe Airbag Pack      │     893.33 │
╰────────────────────────┴────────────╯
```

(Normally you'd write the file in your editor; `printf` just keeps this reproducible.) Inside an interactive session, `.read /tmp/top_products.sql` does the same thing. Don't worry about the `ORDER BY` / `LIMIT` in that query yet — we build up to it in this module.

## 3. Anatomy of a statement

```sql
SELECT 2 + 2 AS four, 'hello, ' || 'SQL' AS greeting;
```

```text
╭──────┬────────────╮
│ four │  greeting  │
╞══════╪════════════╡
│    4 │ hello, SQL │
╰──────┴────────────╯
```

Even this one-liner shows the essential rules:

- A statement **ends with a semicolon**. The CLI waits silently until it sees one — if you press Enter and get a continuation prompt (`...>`) instead of a result, you forgot the `;`.
- `SELECT` doesn't need a table: it can evaluate expressions directly. Useful as a calculator and for testing functions.
- Text uses **single quotes**: `'hello'`. Double quotes mean something else (identifiers — see aliases below). Mixing these up is a classic beginner bug.
- **Keywords are case-insensitive.** `SELECT`, `select`, and `SeLeCt` are identical to the engine:

```sql
select name, unit_price from products order by unit_price limit 3;
```

```text
╭──────────────────┬────────────╮
│       name       │ unit_price │
╞══════════════════╪════════════╡
│ Aqua Dry Bag 20L │       8.18 │
│ Micro Ascender   │       8.72 │
│ Scout Cook Set   │       9.48 │
╰──────────────────┴────────────╯
```

It runs — but this course, and most style guides, write keywords in UPPERCASE and identifiers (table and column names) in lowercase, one clause per line for anything non-trivial. Consistency is a gift to whoever reads your query next, which is usually you, six months later. (Module 12 is the full style guide.)

Comments are for humans and ignored by the engine — `--` to end of line, `/* ... */` for blocks:

```sql
SELECT sku,          -- stock keeping unit
       name,
       unit_price   /* current list price, not
                       necessarily what past orders paid */
FROM products
LIMIT 3;
```

```text
╭────────────┬────────────────────────┬────────────╮
│    sku     │          name          │ unit_price │
╞════════════╪════════════════════════╪════════════╡
│ NK-24-0001 │ Merino Base Layer Top  │     106.69 │
│ NK-08-0002 │ Wall Harness           │      83.69 │
│ NK-17-0003 │ Guard Avalanche Beacon │     602.95 │
╰────────────┴────────────────────────┴────────────╯
```

That comment is not decoration — it documents a real trap in this dataset (`order_items` stores *historical* prices), and commenting *why*, not *what*, is exactly what comments in SQL are for.

## 4. SELECT: column lists vs `*`

The core form is `SELECT <columns> FROM <table>`. Name the columns you want, in the order you want them:

```sql
SELECT product_id, name, unit_price
FROM products
LIMIT 5;
```

```text
╭────────────┬────────────────────────┬────────────╮
│ product_id │          name          │ unit_price │
╞════════════╪════════════════════════╪════════════╡
│          1 │ Merino Base Layer Top  │     106.69 │
│          2 │ Wall Harness           │      83.69 │
│          3 │ Guard Avalanche Beacon │     602.95 │
│          4 │ Moss Approach Shoes    │     267.64 │
│          5 │ Stride Ski Poles       │      92.68 │
╰────────────┴────────────────────────┴────────────╯
```

(`LIMIT 5` caps the output at 5 rows — `products` has 350 and we don't want to scroll. LIMIT gets proper treatment in section 8.)

`SELECT *` means "every column, in schema order":

```sql
SELECT *
FROM suppliers
LIMIT 5;
```

```text
╭─────────────┬─────────────────────────┬─────────┬──────────────────────────────╮
│ supplier_id │          name           │ country │        contact_email         │
╞═════════════╪═════════════════════════╪═════════╪══════════════════════════════╡
│           1 │ Fjellutstyr AS          │ Austria │ fjellutstyr@supplier.example │
│           2 │ Nordic Trail Supply     │ Germany │ nordic@supplier.example      │
│           3 │ Alpin Werke GmbH        │ Germany │ alpin@supplier.example       │
│           4 │ Baltic Gear Oy          │ Sweden  │ baltic@supplier.example      │
│           5 │ Highland Outfitters Ltd │ Finland │ highland@supplier.example    │
╰─────────────┴─────────────────────────┴─────────┴──────────────────────────────╯
```

`SELECT * ... LIMIT 5` is the perfect *exploration* idiom — "show me what this table looks like". In *production* code (pipelines, views, application queries) it's a liability; the Pitfalls section demonstrates why.

## 5. Expressions and aliases

Any column position in a `SELECT` list can hold an **expression**: arithmetic over columns, function calls, string operations. This is where queries start answering business questions instead of just dumping storage.

**Business question: how much does Nordkart make on each product it sells?** Margin is list price minus supplier cost:

```sql
SELECT name, unit_price, unit_cost,
       unit_price - unit_cost AS margin
FROM products
LIMIT 5;
```

```text
╭────────────────────────┬────────────┬───────────┬────────────────────╮
│          name          │ unit_price │ unit_cost │       margin       │
╞════════════════════════╪════════════╪═══════════╪════════════════════╡
│ Merino Base Layer Top  │     106.69 │     51.74 │ 54.949999999999996 │
│ Wall Harness           │      83.69 │     48.26 │              35.43 │
│ Guard Avalanche Beacon │     602.95 │    265.21 │ 337.74000000000007 │
│ Moss Approach Shoes    │     267.64 │     166.7 │             100.94 │
│ Stride Ski Poles       │      92.68 │     41.44 │ 51.240000000000009 │
╰────────────────────────┴────────────┴───────────┴────────────────────╯
```

Two things to notice:

1. `AS margin` is a **column alias** — it names the computed column in the output. Without it you'd get a header like `unit_price - unit_cost`. `AS` is technically optional (`unit_price - unit_cost margin` works) but always write it; the explicit form survives careless edits.
2. `54.949999999999996` is not a bug in SQLite — it's floating-point arithmetic (`REAL` columns are IEEE-754 doubles, in every language and database). Money in `REAL` is a simplification this dataset makes for teaching; production systems use integer cents or `DECIMAL` types (Module 7 discusses this). The display fix is `ROUND(x, 2)`.

```sql
SELECT name, unit_price, unit_cost,
       ROUND(unit_price - unit_cost, 2)                    AS margin,
       ROUND((unit_price - unit_cost) / unit_price * 100, 1) AS margin_pct
FROM products
LIMIT 5;
```

```text
╭────────────────────────┬────────────┬───────────┬────────┬────────────╮
│          name          │ unit_price │ unit_cost │ margin │ margin_pct │
╞════════════════════════╪════════════╪═══════════╪════════╪════════════╡
│ Merino Base Layer Top  │     106.69 │     51.74 │  54.95 │       51.5 │
│ Wall Harness           │      83.69 │     48.26 │  35.43 │       42.3 │
│ Guard Avalanche Beacon │     602.95 │    265.21 │ 337.74 │       56.0 │
│ Moss Approach Shoes    │     267.64 │     166.7 │ 100.94 │       37.7 │
│ Stride Ski Poles       │      92.68 │     41.44 │  51.24 │       55.3 │
╰────────────────────────┴────────────┴───────────┴────────┴────────────╯
```

### The integer-division trap

Dividing two integers performs *integer* division — the fraction is thrown away:

```sql
SELECT 15 / 100 AS int_div,
       15 / 100.0 AS real_div;
```

```text
╭─────────┬──────────╮
│ int_div │ real_div │
╞═════════╪══════════╡
│       0 │     0.15 │
╰─────────┴──────────╯
```

If either operand is a float, the division is float division. This matters *right now*: `order_items.discount_pct` is an INTEGER 0–20, so `discount_pct / 100` is **always 0** — silently zeroing every discount. That is exactly why the canonical **item revenue** definition in `DATASET.md` divides by `100.0`:

> **Item revenue** of an order line = `quantity * unit_price * (1 - discount_pct / 100.0)`

**Business question: what is each order line actually worth?**

```sql
SELECT order_id, product_id, quantity, unit_price, discount_pct,
       ROUND(quantity * unit_price * (1 - discount_pct / 100.0), 2) AS item_revenue
FROM order_items
LIMIT 8;
```

```text
╭──────────┬────────────┬──────────┬────────────┬──────────────┬──────────────╮
│ order_id │ product_id │ quantity │ unit_price │ discount_pct │ item_revenue │
╞══════════╪════════════╪══════════╪════════════╪══════════════╪══════════════╡
│        1 │        241 │        3 │     834.53 │           10 │      2253.23 │
│        1 │        182 │        1 │     340.46 │            0 │       340.46 │
│        1 │        190 │        1 │     399.33 │            0 │       399.33 │
│        1 │        305 │        2 │     267.33 │            0 │       534.66 │
│        1 │        333 │        1 │     132.69 │            0 │       132.69 │
│        2 │        291 │        1 │      219.5 │            0 │        219.5 │
│        3 │          1 │        1 │     106.69 │            0 │       106.69 │
│        3 │        193 │        1 │     547.92 │            0 │       547.92 │
╰──────────┴────────────┴──────────┴────────────┴──────────────┴──────────────╯
```

Memorize that formula — you will type it in nearly every module of this course. Note also that `unit_price` here is the price *at order time*, not the current catalog price.

> **PostgreSQL note:** integer division truncates in PostgreSQL too — this trap is portable. `ROUND(x, 2)` on a double additionally requires a cast in PostgreSQL (`ROUND(x::numeric, 2)`); on `NUMERIC` columns it works directly.

### String concatenation

`||` is the SQL string-concatenation operator (standard SQL — not "or"!).

**Business question: marketing wants a mailing list with display-ready names and locations.**

```sql
SELECT first_name || ' ' || last_name AS full_name,
       city || ', ' || country        AS location,
       email
FROM customers
LIMIT 5;
```

```text
╭─────────────┬────────────────────────┬────────────────────────╮
│  full_name  │        location        │         email          │
╞═════════════╪════════════════════════╪════════════════════════╡
│ Hiro Fisker │ Amsterdam, Netherlands │ hiro.fisker@gmail.com  │
│ Tobias Ek   │ Copenhagen, Denmark    │ tobias.ek@fastmail.com │
│ Ulf Hansen  │ Aalborg, Denmark       │ ulf.hansen@hotmail.com │
│ Frida Holm  │ Uppsala, Sweden        │ frida.holm@yahoo.com   │
│ Bjorn Ahmed │ Oulu, Finland          │ bjorn.ahmed@icloud.com │
╰─────────────┴────────────────────────┴────────────────────────╯
```

Concatenating a number silently converts it to text (`'Order ' || order_id` works). One warning to file away for Module 2: `||` with a `NULL` operand yields `NULL`, so `first_name || ' ' || phone` would wipe out whole rows of output for the 29% of customers with no phone.

### Quoting aliases

If an alias needs spaces or special characters, wrap it in **double quotes** (double quotes = identifiers, single quotes = text values):

```sql
SELECT name,
       ROUND((unit_price - unit_cost) / unit_price * 100, 1) AS "margin %"
FROM products
LIMIT 3;
```

```text
╭────────────────────────┬──────────╮
│          name          │ margin % │
╞════════════════════════╪══════════╡
│ Merino Base Layer Top  │     51.5 │
│ Wall Harness           │     42.3 │
│ Guard Avalanche Beacon │     56.0 │
╰────────────────────────┴──────────╯
```

Pretty for a final report; annoying everywhere else (you'd have to quote it on every reference). Professional habit: `snake_case` aliases while working, human labels only at the last step before a human reads it.

> **PostgreSQL note:** same rule, plus one wrinkle — PostgreSQL folds unquoted identifiers to lowercase, so `SELECT x AS Margin` comes back as `margin` unless you write `"Margin"`. Avoid the whole issue: stick to lowercase snake_case.

## 6. DISTINCT

`DISTINCT` collapses duplicate rows in the result.

**Business question: what states can an order be in?** (You saw it in the CHECK constraint; here's how you'd discover it from the data.)

```sql
SELECT DISTINCT status
FROM orders;
```

```text
╭───────────╮
│  status   │
╞═══════════╡
│ delivered │
│ cancelled │
│ shipped   │
│ paid      │
│ pending   │
│ returned  │
╰───────────╯
```

Six thousand orders in, six rows out. Note the order they came back in looks arbitrary — because it is; more on that in the ORDER BY section and the Pitfalls.

With multiple columns, `DISTINCT` applies to the **whole row** — it keeps every distinct *combination*:

**Business question: which payment method / status combinations actually occur?** (A good data-quality probe: are there refunds that failed? pending bank transfers?)

```sql
SELECT DISTINCT method, status
FROM payments;
```

```text
╭───────────────┬──────────╮
│    method     │  status  │
╞═══════════════╪══════════╡
│ paypal        │ captured │
│ bank_transfer │ captured │
│ klarna        │ captured │
│ card          │ captured │
│ bank_transfer │ pending  │
│ klarna        │ failed   │
│ card          │ failed   │
│ paypal        │ failed   │
│ bank_transfer │ failed   │
│ refund        │ captured │
│ paypal        │ pending  │
│ card          │ pending  │
│ klarna        │ pending  │
╰───────────────┴──────────╯
```

13 combinations, not 5 methods and not 3 statuses — every pair that exists somewhere in the table. Reading it: `refund` only ever appears as `captured` (no failed refunds), and every real payment method has captured/failed/pending rows. There is **no** "DISTINCT just this column, please" syntax — a common misreading demolished in the Pitfalls section. When you want "one row per group with other columns summarized," that's `GROUP BY`, coming in Module 3.

## 7. ORDER BY

Here is the most important guarantee in this module: **a query's row order is undefined unless you say `ORDER BY`.** Whatever order you observe without it is an implementation accident. `ORDER BY` is the only contract.

**Business question: what are our ten most expensive products?**

```sql
SELECT name, unit_price
FROM products
ORDER BY unit_price DESC
LIMIT 10;
```

```text
╭─────────────────────────┬────────────╮
│          name           │ unit_price │
╞═════════════════════════╪════════════╡
│ Drift Inflatable Kayak  │    1004.85 │
│ Fjord Sit-on-Top Kayak  │     934.86 │
│ Probe Airbag Pack       │     893.33 │
│ Rescue Avalanche Beacon │     834.53 │
│ Tele Touring Skis       │     775.98 │
│ Skerry Spray Skirt      │     773.95 │
│ Drift Touring Skis      │     745.19 │
│ Nordic Tent 2P          │     744.79 │
│ Probe Snow Shovel       │     744.12 │
│ Alpine Tunnel Tent      │     734.69 │
╰─────────────────────────┴────────────╯
```

`ASC` (ascending) is the default; `DESC` reverses. `ORDER BY x DESC LIMIT n` is *the* top-N idiom.

### Multiple sort keys

Later keys break ties in earlier keys.

**Business question: produce a customer directory grouped by country, then city, then surname.**

```sql
SELECT country, city, last_name, first_name
FROM customers
ORDER BY country, city, last_name
LIMIT 10;
```

```text
╭─────────┬───────────┬───────────┬────────────╮
│ country │   city    │ last_name │ first_name │
╞═════════╪═══════════╪═══════════╪════════════╡
│ Austria │ Innsbruck │ Berg      │ Petra      │
│ Austria │ Innsbruck │ Bergstrom │ Ida        │
│ Austria │ Innsbruck │ Kowalski  │ Emma       │
│ Austria │ Innsbruck │ Kron      │ Priya      │
│ Austria │ Innsbruck │ Okafor    │ Freja      │
│ Austria │ Innsbruck │ Olsen     │ Mikael     │
│ Austria │ Innsbruck │ Sandberg  │ Mats       │
│ Austria │ Innsbruck │ Sten      │ Ebba       │
│ Austria │ Innsbruck │ Vik       │ Otto       │
│ Austria │ Salzburg  │ Andersson │ Thea       │
╰─────────┴───────────┴───────────┴────────────╯
```

Each key can have its own direction. **Newest signup per country listing:**

```sql
SELECT last_name || ', ' || first_name AS customer,
       country,
       created_at
FROM customers
ORDER BY country ASC, created_at DESC
LIMIT 8;
```

```text
╭────────────────┬─────────┬─────────────────────╮
│    customer    │ country │     created_at      │
╞════════════════╪═════════╪═════════════════════╡
│ Wall, Anders   │ Austria │ 2026-07-03 06:35:09 │
│ Dahl, Gunnar   │ Austria │ 2026-05-03 11:59:46 │
│ Hagen, Gunnar  │ Austria │ 2026-03-26 21:10:44 │
│ Blom, Elin     │ Austria │ 2026-03-17 22:55:13 │
│ Nyström, Sofia │ Austria │ 2026-02-27 01:21:30 │
│ Olsen, Rune    │ Austria │ 2026-02-11 13:41:05 │
│ Fisker, Anders │ Austria │ 2025-10-05 17:50:29 │
│ Kowalski, Emma │ Austria │ 2025-09-06 20:17:48 │
╰────────────────┴─────────┴─────────────────────╯
```

Those ISO-8601 text timestamps sort correctly as plain strings — that's the entire reason the format exists.

### NULLs in ORDER BY

SQLite treats `NULL` as smaller than everything: ascending sorts put NULLs **first**, descending puts them **last**.

**Business question: which shipments were delivered earliest?**

```sql
SELECT shipment_id, carrier, delivered_at
FROM shipments
ORDER BY delivered_at
LIMIT 5;
```

```text
╭─────────────┬──────────┬──────────────╮
│ shipment_id │ carrier  │ delivered_at │
╞═════════════╪══════════╪══════════════╡
│           2 │ DHL      │              │
│          34 │ PostNord │              │
│          51 │ PostNord │              │
│          62 │ Bring    │              │
│          83 │ Bring    │              │
╰─────────────┴──────────┴──────────────╯
```

Not what we asked for: these are the 153 *in-transit* shipments (`delivered_at IS NULL` — the box display shows NULL as blank), sorted to the front. Fix with `NULLS LAST` (SQLite ≥ 3.30):

```sql
SELECT shipment_id, carrier, delivered_at
FROM shipments
ORDER BY delivered_at NULLS LAST
LIMIT 5;
```

```text
╭─────────────┬──────────┬─────────────────────╮
│ shipment_id │ carrier  │    delivered_at     │
╞═════════════╪══════════╪═════════════════════╡
│        4714 │ Bring    │ 2023-01-10 07:01:50 │
│        3948 │ PostNord │ 2023-01-12 01:51:33 │
│        1224 │ UPS      │ 2023-01-13 03:44:52 │
│        4668 │ Bring    │ 2023-01-17 10:44:58 │
│        4214 │ Bring    │ 2023-01-25 01:32:45 │
╰─────────────┴──────────┴─────────────────────╯
```

> **PostgreSQL note:** PostgreSQL sorts NULLs as *largest* — exactly the opposite default (ASC → NULLs last, DESC → NULLs first). Portable queries state `NULLS FIRST`/`NULLS LAST` explicitly whenever a sort column can be NULL.

### Ordering by alias, expression, or position

You can sort by an alias defined in the `SELECT` list — usually the cleanest option for computed columns:

**Business question: top 5 products by absolute margin.**

```sql
SELECT name,
       ROUND(unit_price - unit_cost, 2) AS margin
FROM products
ORDER BY margin DESC
LIMIT 5;
```

```text
╭─────────────────────────┬────────╮
│          name           │ margin │
╞═════════════════════════╪════════╡
│ Drift Inflatable Kayak  │ 505.76 │
│ Rescue Avalanche Beacon │  483.0 │
│ Tele Touring Skis       │ 440.94 │
│ Nordic Tent 2P          │ 400.55 │
│ Wave Inflatable Kayak   │ 388.41 │
╰─────────────────────────┴────────╯
```

You may also order by a raw expression (`ORDER BY unit_price - unit_cost DESC` — even if it isn't in the SELECT list at all) or by output-column *position*:

```sql
SELECT name, unit_price
FROM products
ORDER BY 2 DESC
LIMIT 3;
```

```text
╭────────────────────────┬────────────╮
│          name          │ unit_price │
╞════════════════════════╪════════════╡
│ Drift Inflatable Kayak │    1004.85 │
│ Fjord Sit-on-Top Kayak │     934.86 │
│ Probe Airbag Pack      │     893.33 │
╰────────────────────────┴────────────╯
```

`ORDER BY 2` means "second output column". It works, you'll meet it in the wild, and you should not write it: reorder the SELECT list and the query silently sorts by something else. Names survive edits; positions don't.

## 8. LIMIT and OFFSET

`LIMIT n` returns at most *n* rows; `OFFSET m` skips the first *m* rows first. Together they paginate.

**Business question: the catalog team reviews products alphabetically, 10 per page. Give them page 1 and page 2.**

```sql
SELECT sku, name
FROM products
ORDER BY name, product_id
LIMIT 10;
```

```text
╭────────────┬───────────────────────╮
│    sku     │         name          │
╞════════════╪═══════════════════════╡
│ NK-08-0293 │ Aero Big Wall Harness │
│ NK-08-0103 │ Aero Chest Harness    │
│ NK-08-0246 │ Aero Harness          │
│ NK-08-0091 │ Aero Kids Harness     │
│ NK-02-0344 │ Alpine Dome Tent      │
│ NK-02-0298 │ Alpine Tent 2P        │
│ NK-02-0312 │ Alpine Tunnel Tent    │
│ NK-12-0126 │ Alu Folding Poles     │
│ NK-12-0020 │ Alu Trekking Poles    │
│ NK-07-0256 │ Anchor Cordelette     │
╰────────────┴───────────────────────╯
```

```sql
SELECT sku, name
FROM products
ORDER BY name, product_id
LIMIT 10 OFFSET 10;
```

```text
╭────────────┬────────────────────────╮
│    sku     │          name          │
╞════════════╪════════════════════════╡
│ NK-07-0206 │ Anchor Rope 60m        │
│ NK-07-0317 │ Anchor Sling 120cm     │
│ NK-07-0106 │ Anchor Static Rope 40m │
│ NK-21-0171 │ Aqua Dry Bag 10L       │
│ NK-21-0086 │ Aqua Dry Bag 20L       │
│ NK-21-0109 │ Aqua Dry Bag 40L       │
│ NK-21-0132 │ Aqua Phone Case        │
│ NK-03-0053 │ Aurora Down Bag        │
│ NK-23-0014 │ Aurora Down Jacket     │
│ NK-23-0079 │ Aurora Insulated Parka │
╰────────────┴────────────────────────╯
```

Page *k* (1-based) of size *n* is `LIMIT n OFFSET (k-1)*n`. Three professional caveats:

1. **Pagination requires a deterministic total order.** That's why the query sorts by `name, product_id` — if two products ever shared a name, plain `ORDER BY name` would leave their relative order undefined, and a product could appear on both page 1 and page 2 (or on neither). Always add a unique tie-breaker column (here, the primary key).
2. **`LIMIT` without `ORDER BY` means "any n rows"** — occasionally what you want for a peek, never what you want for a "top 10".
3. **OFFSET does the skipped work anyway.** The engine computes and discards the first *m* rows, so page 1,000 is far slower than page 1. Fine for humans clicking through pages; wrong for batch processing. The scalable alternative (keyset pagination, `WHERE key > last_seen`) needs Module 2's `WHERE` — we'll revisit.

> **PostgreSQL note:** `LIMIT`/`OFFSET` work identically. The SQL standard spells it `OFFSET m ROWS FETCH FIRST n ROWS ONLY`, which PostgreSQL also accepts; SQLite does not.

## Pitfalls

### Pitfall 1: `SELECT *` in production code

```sql
-- BAD: a pipeline that "just needs order status" but ships every column
SELECT *
FROM orders
LIMIT 3;
```

```text
╭──────────┬─────────────┬────────────┬───────────┬───────────────┬─────────────────────╮
│ order_id │ customer_id │ address_id │  status   │ shipping_cost │     ordered_at      │
╞══════════╪═════════════╪════════════╪═══════════╪═══════════════╪═════════════════════╡
│        1 │         490 │        688 │ delivered │           4.9 │ 2026-03-01 22:15:44 │
│        2 │         514 │        725 │ cancelled │           9.9 │ 2023-08-23 13:27:07 │
│        3 │         321 │        443 │ shipped   │           0.0 │ 2026-07-07 18:14:23 │
╰──────────┴─────────────┴────────────┴───────────┴───────────────┴─────────────────────╯
```

The query runs — the damage is structural, not syntactic:

- **Wasted I/O.** You needed 3 of 6 columns; you read, transferred, and parsed all 6. On a 6-row demo, irrelevant; on a billion-row fact table in a column-store warehouse, `SELECT *` can multiply your scan cost (and your bill) several-fold.
- **Schema drift.** Your output columns are whatever the table happens to contain *today*. When someone adds `internal_fraud_score` to `orders` next quarter, it silently starts flowing into your export, your dashboard, maybe your customer-facing CSV. Downstream code that relies on column order breaks outright.
- **Unreadable intent.** A reviewer can't tell which columns the pipeline actually depends on.

The fix — say what you mean:

```sql
SELECT order_id, status, ordered_at
FROM orders
LIMIT 3;
```

```text
╭──────────┬───────────┬─────────────────────╮
│ order_id │  status   │     ordered_at      │
╞══════════╪═══════════╪═════════════════════╡
│        1 │ delivered │ 2026-03-01 22:15:44 │
│        2 │ cancelled │ 2023-08-23 13:27:07 │
│        3 │ shipped   │ 2026-07-07 18:14:23 │
╰──────────┴───────────┴─────────────────────╯
```

Rule of thumb: `SELECT *` for interactive exploration, explicit columns for anything that gets saved, scheduled, or shared.

### Pitfall 2: assuming row order without ORDER BY

```sql
-- BAD: "the first five customers" — no ORDER BY, so no such guarantee
SELECT customer_id, first_name, last_name
FROM customers
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────╮
│ customer_id │ first_name │ last_name │
╞═════════════╪════════════╪═══════════╡
│           1 │ Hiro       │ Fisker    │
│           2 │ Tobias     │ Ek        │
│           3 │ Ulf        │ Hansen    │
│           4 │ Frida      │ Holm      │
│           5 │ Bjorn      │ Ahmed     │
╰─────────────┴────────────┴───────────╯
```

It *looks* correct: SQLite happened to scan the table in primary-key order. That is an implementation detail, not a promise — a different query plan (an index scan, a parallel worker in another engine, a `VACUUM` that rewrote the table) returns the same rows in a different sequence. SQLite ships a built-in chaos switch, `reverse_unordered_selects`, precisely so developers can flush out this bug — it legally reverses every order you didn't lock down:

```sql
PRAGMA reverse_unordered_selects = ON;
SELECT customer_id, first_name, last_name
FROM customers
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────╮
│ customer_id │ first_name │ last_name │
╞═════════════╪════════════╪═══════════╡
│         800 │ Noah       │ Yilmaz    │
│         799 │ Ebba       │ Larsson   │
│         798 │ Karl       │ Ivanov    │
│         797 │ Linnea     │ Nyström   │
│         796 │ Lars       │ Sund      │
╰─────────────┴────────────┴───────────╯
```

Same table, same SQL, *entirely different rows* — and both results are correct, because the query never specified an order. Combined with `LIMIT`, an unspecified order silently changes **which rows you get**, not just their arrangement. The fix costs one line:

```sql
SELECT customer_id, first_name, last_name
FROM customers
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────╮
│ customer_id │ first_name │ last_name │
╞═════════════╪════════════╪═══════════╡
│           1 │ Hiro       │ Fisker    │
│           2 │ Tobias     │ Ek        │
│           3 │ Ulf        │ Hansen    │
│           4 │ Frida      │ Holm      │
│           5 │ Bjorn      │ Ahmed     │
╰─────────────┴────────────┴───────────╯
```

This version returns the same five rows under any plan, any pragma, any engine. (The pragma is per-connection, so a fresh session is unaffected; if you set it in your interactive session, turn it off:)

```sql
PRAGMA reverse_unordered_selects = OFF;
```

```text
```

(No output — pragmas that set a value print nothing.)

### Pitfall 3: DISTINCT applies to the whole row, not one column

A very common misreading: "I want each country once, with a city for context — I'll put DISTINCT in front of country."

```sql
-- BAD: hoping DISTINCT deduplicates only `country`
SELECT DISTINCT country, city
FROM customers
ORDER BY country
LIMIT 8;
```

```text
╭─────────┬────────────╮
│ country │    city    │
╞═════════╪════════════╡
│ Austria │ Salzburg   │
│ Austria │ Innsbruck  │
│ Austria │ Vienna     │
│ Denmark │ Copenhagen │
│ Denmark │ Aalborg    │
│ Denmark │ Aarhus     │
│ Denmark │ Odense     │
│ Finland │ Oulu       │
╰─────────┴────────────╯
```

Austria appears three times. `DISTINCT` is not a function applied to the column it happens to sit next to — it's a set-level operation on the entire output row, so you get every distinct `(country, city)` *pair*. There is no per-column DISTINCT. If the question is "which countries?", select only the column you're deduplicating:

```sql
SELECT DISTINCT country
FROM customers
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

If the question is genuinely "one row per country, plus *some* other columns" (a representative city, a count of customers), that's grouping and aggregation — Module 3's whole job.

## Exercises

Answer each with a single query (or, for the warm-up CLI drill, CLI commands). No `WHERE` needed anywhere — everything is solvable with this module's toolkit. Solutions are in `solutions/01-first-queries.md`; wrestle first, peek second.

### Warm-up

1. **Warehouse tour.** Using only CLI commands and `SELECT ... LIMIT`, list all 12 tables, then inspect the two tables we haven't touched yet: show the schema of `events` and of `price_history`, and look at 3 rows of each. In one sentence each, say what a row represents.
2. **Bargain bin.** The merchandising team wants the 10 cheapest products in the catalog: `sku`, `name`, and `unit_price`, cheapest first.
3. **Status inventory.** Which distinct order statuses occur in `orders`, and which distinct event types occur in `events`? (Two queries; sort each alphabetically.)

### Core

4. **Mailing list.** Produce the first 15 rows of a contact list for the CRM import: one column with the customer's full name, their `email`, and one column formatted `city, country` — sorted by last name, then first name.
5. **Margin leaderboard.** For the pricing review: each product's `name`, `unit_price`, `unit_cost`, absolute margin (rounded to 2 decimals) and margin percentage of the sale price (rounded to 1 decimal), showing the 10 products with the highest margin percentage. Break ties by name.
6. **Whale lines.** Using the canonical item-revenue formula from `DATASET.md`, find the 10 most valuable individual order lines: `order_id`, `product_id`, `quantity`, `unit_price`, `discount_pct`, and the computed `item_revenue`, largest first.
7. **Catalog, page 3.** The catalog team reviews products alphabetically by name, 20 per page. Produce exactly page 3 (`sku`, `name`, `unit_price`) — and make the pagination deterministic.
8. **Payment matrix.** List every distinct `(method, status)` combination in `payments`, sorted by method then status. Which method never fails?
9. **Fresh reviews.** Show the 10 most recent product reviews: `product_id`, `rating`, `review_text`, `created_at`, newest first. Something is odd about `review_text` in several rows — what is it, and is it a data bug? (Check `DATASET.md` before answering.)

### Challenge

10. **Refund radar.** Finance wants the 5 largest refunds ever issued: `payment_id`, `order_id`, `amount`, `method`, and `paid_at`. Recall from `DATASET.md` how refunds are stored in `payments` — get the *largest* refunds at the top.
11. **First deliveries.** Show the 5 earliest-delivered shipments (`shipment_id`, `order_id`, `carrier`, `delivered_at`). Warning: the naive query returns five blank dates — explain why, then fix it.
12. **Line labels.** For the 5 order lines with the lowest `order_id` (break ties by `product_id`), build a single text column `line_label` that renders like `Order 1: 3 x 834.53 (10% off)`, using only `||`. What did SQLite do with the numeric columns to make this work?

## Key takeaways

- **Mental model:** tables = typed columns × rows; primary keys identify rows; foreign keys link tables; SQL is declarative — you specify *what*, the planner picks *how*.
- **CLI:** `.tables`, `.schema [table]`, `.mode box`, `.headers on`, `.read file.sql`, `.quit`; dot commands are the CLI's, not SQL. `sqlite3 -box db "query"` for one-shots; put defaults in `~/.sqliterc`.
- **Statements** end with `;`. Keywords are case-insensitive (write them UPPERCASE anyway). Comments: `-- line`, `/* block */`.
- **Strings vs identifiers:** `'single quotes'` for text values, `"double quotes"` for identifiers (e.g., aliases with spaces).
- `SELECT a, b FROM t` — explicit column lists in anything durable; `SELECT *` only for interactive peeking.
- **Expressions:** any select-list slot can compute: `+ - * /`, `||` for concatenation, `ROUND(x, n)` for display. Integer ÷ integer truncates — divide by `100.0`, as in the canonical item revenue: `quantity * unit_price * (1 - discount_pct / 100.0)`.
- **Aliases:** `expr AS name`; you can `ORDER BY` an alias; avoid ordering by column position.
- **DISTINCT** deduplicates the *entire* result row; multi-column DISTINCT = distinct combinations; no per-column form exists.
- **Row order is undefined without ORDER BY** — always order anything a human or a `LIMIT` will consume. NULLs sort first in SQLite ASC (opposite in PostgreSQL): state `NULLS LAST` explicitly when it matters.
- **ORDER BY key1 [ASC|DESC], key2 ...** — later keys break ties; add a unique tie-breaker for deterministic pagination.
- **LIMIT n OFFSET m** paginates but the engine still computes the skipped rows; top-N = `ORDER BY ... DESC LIMIT n`.
