# Module 2 — Filtering & NULL

Almost every production query begins with a filter: *which* orders, *which*
customers, *which* time window. Getting `WHERE` right is therefore the single
highest-leverage skill in SQL — and the single biggest source of silently wrong
numbers, because SQL's logic is not two-valued but *three*-valued: every
condition can be TRUE, FALSE, or NULL, and `WHERE` keeps only the TRUE rows.
This module teaches the filtering toolkit and then drills into NULL semantics
until they are second nature, because a data engineer who misjudges NULL ships
dashboards that are confidently wrong.

All queries in this module only *read* data, so run them directly against
`shop.db` from the course root:

```bash
sqlite3 -box shop.db
```

## What you'll learn

- Filter rows with `WHERE` and the comparison operators `=`, `<>`/`!=`, `<`, `<=`, `>`, `>=`
- Combine conditions with `AND`, `OR`, `NOT` — and control precedence with parentheses
- Match against sets with `IN` / `NOT IN`
- Use `BETWEEN` correctly (it's inclusive on both ends — and dangerous with timestamps)
- Pattern-match with `LIKE`, `%`, `_`, and `ESCAPE`, and know how case-sensitivity differs between SQLite and PostgreSQL
- Reason in three-valued logic: why `NULL = NULL` isn't true, `IS NULL` / `IS NOT NULL`, and how NULL flows through `AND`/`OR`/`NOT`
- Handle NULLs deliberately with `COALESCE`, `NULLIF`, and `IFNULL`
- Compute conditional values with `CASE` (simple and searched forms), in `SELECT` and in `ORDER BY`
- Filter on dates the professional way: ISO-8601 string comparison, `date()`/`strftime()`, and half-open ranges `[start, next_start)`

## WHERE: keeping only the rows you want

`WHERE` sits between `FROM` and `ORDER BY` and evaluates a condition for every
row. A row survives only if the condition evaluates to TRUE — remember that
phrasing; it becomes crucial in the NULL section.

Business question: *which products in the catalog cost more than 800?* (The
buying team reviews everything at the top of the price range each quarter.)

```sql
SELECT product_id, name, unit_price
FROM products
WHERE unit_price > 800
ORDER BY unit_price DESC;
```

```text
╭────────────┬─────────────────────────┬────────────╮
│ product_id │          name           │ unit_price │
╞════════════╪═════════════════════════╪════════════╡
│         46 │ Drift Inflatable Kayak  │    1004.85 │
│        289 │ Fjord Sit-on-Top Kayak  │     934.86 │
│        238 │ Probe Airbag Pack       │     893.33 │
│        241 │ Rescue Avalanche Beacon │     834.53 │
╰────────────┴─────────────────────────┴────────────╯
```

Four products out of 350. Note the logical evaluation order: SQLite scans
`products`, applies the `WHERE` test to each row, and only then sorts the
survivors. `ORDER BY` never changes *which* rows you get, only their order.

Comparisons work on text too. Text comparison in SQLite is byte-wise and
**case-sensitive** for `=` (unlike `LIKE`, as we'll see):

```sql
SELECT first_name, last_name, city
FROM customers
WHERE country = 'Norway'
ORDER BY last_name
LIMIT 5;
```

```text
╭────────────┬───────────┬───────────╮
│ first_name │ last_name │   city    │
╞════════════╪═══════════╪═══════════╡
│ Ragnar     │ Ahmed     │ Trondheim │
│ Linnea     │ Ahmed     │ Bergen    │
│ Lea        │ Berg      │ Oslo      │
│ Mikael     │ Bergstrom │ Trondheim │
│ Jonas      │ Blom      │ Bergen    │
╰────────────┴───────────┴───────────╯
```

(98 rows total; `LIMIT 5` for display.) `'norway'` would match nothing —
string literals use single quotes and must match the stored casing exactly.

"Not equal" is spelled `<>` in the SQL standard; `!=` is a universally
supported synonym. Business question: *which orders are not yet in a customer's
hands — everything except `delivered`?*

```sql
SELECT order_id, status, ordered_at
FROM orders
WHERE status <> 'delivered'
ORDER BY ordered_at DESC
LIMIT 5;
```

```text
╭──────────┬─────────┬─────────────────────╮
│ order_id │ status  │     ordered_at      │
╞══════════╪═════════╪═════════════════════╡
│     4481 │ pending │ 2026-07-14 21:44:48 │
│     2693 │ pending │ 2026-07-14 21:03:53 │
│     1357 │ pending │ 2026-07-14 20:13:11 │
│     3745 │ pending │ 2026-07-14 19:00:34 │
│     2669 │ pending │ 2026-07-14 18:28:06 │
╰──────────┴─────────┴─────────────────────╯
```

(793 rows total.) This works cleanly here because `status` is never NULL. When
the column *can* be NULL, `<>` has a trap we dissect in the Pitfalls section —
it is the most important three lines in this module.

## AND, OR, NOT — and why parentheses are not optional

Conditions combine with `AND` (both must hold), `OR` (at least one must hold),
and `NOT` (inverts). Business question: *which currently-sold products are
impulse-buy cheap — active and under 25?*

```sql
SELECT name, unit_price
FROM products
WHERE is_active = 1
  AND unit_price < 25
ORDER BY unit_price
LIMIT 5;
```

```text
╭────────────────────┬────────────╮
│        name        │ unit_price │
╞════════════════════╪════════════╡
│ Aqua Dry Bag 20L   │       8.18 │
│ Micro Ascender     │       8.72 │
│ Scout Cook Set     │       9.48 │
│ Micro Belay Device │      10.96 │
│ Micro Carabiner    │       12.2 │
╰────────────────────┴────────────╯
```

(13 rows total.)

**Precedence:** `NOT` binds tightest, then `AND`, then `OR`. So
`a OR b AND c` means `a OR (b AND c)` — almost never what a human sentence
means. The professional rule: **the moment a `WHERE` clause mixes `AND` and
`OR`, add parentheses**, even when precedence happens to be on your side.
Business question: *which Swedish or Norwegian customers can we legally market
to?*

```sql
SELECT customer_id, first_name, last_name, country, marketing_opt_in
FROM customers
WHERE (country = 'Sweden' OR country = 'Norway')
  AND marketing_opt_in = 1
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────┬─────────┬──────────────────╮
│ customer_id │ first_name │ last_name │ country │ marketing_opt_in │
╞═════════════╪════════════╪═══════════╪═════════╪══════════════════╡
│          10 │ Nora       │ Karlsson  │ Sweden  │                1 │
│          12 │ Wilma      │ Magnusson │ Sweden  │                1 │
│          40 │ Freja      │ Nilsson   │ Sweden  │                1 │
│          44 │ Linnea     │ Kowalski  │ Norway  │                1 │
│          81 │ Leif       │ Andersson │ Sweden  │                1 │
╰─────────────┴────────────┴───────────┴─────────┴──────────────────╯
```

(106 rows total.) The Pitfalls section shows exactly what goes wrong when the
parentheses are dropped.

`NOT` inverts a condition. Since SQLite booleans are just integers 0/1, you
can even negate a flag column directly — *which products are discontinued?*

```sql
SELECT name, unit_price
FROM products
WHERE NOT is_active
ORDER BY unit_price DESC
LIMIT 5;
```

```text
╭──────────────────────────┬────────────╮
│           name           │ unit_price │
╞══════════════════════════╪════════════╡
│ Fjell Touring Skis       │     558.19 │
│ Randonee Ski Skins       │     547.92 │
│ Guard Airbag Pack        │     439.82 │
│ Drift Cross-Country Skis │     411.62 │
│ Vector Altimeter Watch   │     353.09 │
╰──────────────────────────┴────────────╯
```

(26 rows total.) The explicit
`is_active = 0` says the same thing and is clearer to readers; prefer it.

> **PostgreSQL note:** PostgreSQL has a real `boolean` type, so flags are
> written `WHERE is_active` / `WHERE NOT is_active` naturally, and comparing a
> boolean to an integer (`is_active = 1`) is a type error. SQLite's 0/1
> convention makes both spellings work.

## IN: membership in a list

`x IN (a, b, c)` is shorthand for `x = a OR x = b OR x = c` — shorter, clearer,
and immune to the precedence trap. Business question: *which customers live in
our Nordic home markets?*

```sql
SELECT first_name, last_name, country
FROM customers
WHERE country IN ('Sweden', 'Norway', 'Denmark', 'Finland')
ORDER BY customer_id
LIMIT 5;
```

```text
╭────────────┬───────────┬─────────╮
│ first_name │ last_name │ country │
╞════════════╪═══════════╪═════════╡
│ Tobias     │ Ek        │ Denmark │
│ Ulf        │ Hansen    │ Denmark │
│ Frida      │ Holm      │ Sweden  │
│ Bjorn      │ Ahmed     │ Finland │
│ Hiro       │ Wall      │ Sweden  │
╰────────────┴───────────┴─────────╯
```

(439 rows total.) `NOT IN` gives the complement — the export markets:

```sql
SELECT first_name, last_name, country
FROM customers
WHERE country NOT IN ('Sweden', 'Norway', 'Denmark', 'Finland')
ORDER BY customer_id
LIMIT 5;
```

```text
╭────────────┬───────────┬─────────────╮
│ first_name │ last_name │   country   │
╞════════════╪═══════════╪═════════════╡
│ Hiro       │ Fisker    │ Netherlands │
│ Mats       │ Sjoberg   │ Germany     │
│ Mikael     │ Karlsson  │ Germany     │
│ Priya      │ Tanaka    │ Germany     │
│ Gunnar     │ Ivanov    │ Germany     │
╰────────────┴───────────┴─────────────╯
```

(361 rows total — and 439 + 361 = 800, the whole table, because `country` is
never NULL here. Hold that thought: with NULLs in play, `IN` and `NOT IN` stop
being clean complements. There's a flag planted in the Pitfalls section, and
the full trap is dissected in Module 4 when `IN` meets subqueries.)

## BETWEEN: inclusive on both ends

`x BETWEEN lo AND hi` means `x >= lo AND x <= hi` — **both endpoints
included**. Business question: *what's in the 100–150 mid-market price
segment?*

```sql
SELECT name, unit_price
FROM products
WHERE unit_price BETWEEN 100 AND 150
ORDER BY unit_price
LIMIT 5;
```

```text
╭──────────────────────┬────────────╮
│         name         │ unit_price │
╞══════════════════════╪════════════╡
│ Flex Ski Poles       │     101.75 │
│ Probe Probe 240cm    │     102.02 │
│ Lock Belay Device    │     103.41 │
│ Aero Kids Harness    │     103.52 │
│ Packrat Backpack 50L │      104.0 │
╰──────────────────────┴────────────╯
```

(56 rows total.) A product priced exactly 100.00 or 150.00 would be included.
For prices that's usually what you want. For **timestamps it almost never is**
— the inclusive upper bound is one of the classic date bugs, demonstrated in
Pitfalls and replaced by the half-open range idiom at the end of this module.

## LIKE: pattern matching

`LIKE` matches text against a pattern with two wildcards:

- `%` — any sequence of characters, including none
- `_` — exactly one character

Business question: *the merchandiser wants every jacket in the catalog, priced
high to low.*

```sql
SELECT name, unit_price
FROM products
WHERE name LIKE '%jacket%'
ORDER BY unit_price DESC;
```

```text
╭──────────────────────────┬────────────╮
│           name           │ unit_price │
╞══════════════════════════╪════════════╡
│ Aurora Down Jacket       │      501.7 │
│ Drizzle Down Jacket      │     474.94 │
│ Storm Down Jacket        │     471.87 │
│ Aurora Softshell Jacket  │     393.11 │
│ Drizzle Rain Jacket      │     374.67 │
│ Vind Rain Jacket         │     344.17 │
│ Storm Rain Jacket        │     300.82 │
│ Fjell Rain Jacket        │     288.42 │
│ Fjell Down Jacket        │      226.6 │
│ Drizzle Softshell Jacket │     180.66 │
│ Aurora Rain Jacket       │     123.76 │
╰──────────────────────────┴────────────╯
```

Notice: the pattern says `jacket`, the data says `Jacket`, and it matched
anyway. **SQLite's `LIKE` is case-insensitive** for ASCII letters (only ASCII
— `Ö` vs `ö` will *not* match). This is convenient for search boxes and a
portability trap, because:

> **PostgreSQL note:** In PostgreSQL, `LIKE` is **case-sensitive**. For
> case-insensitive matching PostgreSQL offers `ILIKE`
> (`name ILIKE '%jacket%'`). A query relying on SQLite's forgiving `LIKE` will
> silently return fewer rows on PostgreSQL. When porting, decide explicitly:
> `ILIKE`, or `lower(name) LIKE '%jacket%'` (which works everywhere).

`_` matches exactly one character — useful for fixed-width codes. Nordkart
SKUs are `NK-<2-digit category>-<4 digits>`, so category 12's products are:

```sql
SELECT sku, name
FROM products
WHERE sku LIKE 'NK-12-____'
ORDER BY sku
LIMIT 5;
```

```text
╭────────────┬───────────────────────╮
│    sku     │         name          │
╞════════════╪═══════════════════════╡
│ NK-12-0005 │ Stride Ski Poles      │
│ NK-12-0015 │ Stride Trekking Poles │
│ NK-12-0016 │ Stride Folding Poles  │
│ NK-12-0019 │ Peak Ski Poles        │
│ NK-12-0020 │ Alu Trekking Poles    │
╰────────────┴───────────────────────╯
```

(13 rows total.) The four `_` insist on exactly four trailing characters — a
five-digit suffix would not match.

### ESCAPE: matching a literal % or _

What if the *data* contains a wildcard character? Say we want event types that
contain a literal underscore (multi-word event names like `page_view`). The
naive attempt:

```sql
-- BAD: '_' is a wildcard, so this matches ANY string with at least one character
SELECT DISTINCT event_type
FROM events
WHERE event_type LIKE '%_%'
ORDER BY event_type;
```

```text
╭────────────────╮
│   event_type   │
╞════════════════╡
│ add_to_cart    │
│ begin_checkout │
│ page_view      │
│ search         │
╰────────────────╯
```

`search` has no underscore, yet it matched — because `%_%` just means "at
least one character". Declare an escape character to make `_` literal:

```sql
SELECT DISTINCT event_type
FROM events
WHERE event_type LIKE '%\_%' ESCAPE '\'
ORDER BY event_type;
```

```text
╭────────────────╮
│   event_type   │
╞════════════════╡
│ add_to_cart    │
│ begin_checkout │
│ page_view      │
╰────────────────╯
```

Now only genuine underscores match. Any character can serve as the escape;
`\` is conventional.

## NULL and three-valued logic — the heart of the module

NULL means **unknown / absent**, not zero and not empty string. That single
idea drives everything else: any comparison with an unknown value has an
unknown answer. Watch:

```sql
SELECT NULL = NULL   AS null_eq_null,
       NULL <> NULL  AS null_ne_null,
       1 = NULL      AS one_eq_null;
```

```text
╭──────────────┬──────────────┬─────────────╮
│ null_eq_null │ null_ne_null │ one_eq_null │
╞══════════════╪══════════════╪═════════════╡
│              │              │             │
╰──────────────┴──────────────┴─────────────╯
```

All three cells are *empty* — that's how `sqlite3`'s box mode renders NULL
(you can make NULLs visible with the CLI setting `.nullvalue NULL`; we keep
the default here so outputs match what you see out of the box). `NULL = NULL`
is not TRUE, and it's not FALSE either — it is NULL. The reasoning: "is one
unknown value equal to another unknown value?" — *unknown*. We can prove the
result really is NULL:

```sql
SELECT typeof(NULL = NULL) AS result_type;
```

```text
╭─────────────╮
│ result_type │
╞═════════════╡
│ null        │
╰─────────────╯
```

So SQL conditions have **three** possible values: TRUE, FALSE, NULL. And the
rule from the start of this module now gets its teeth:

> **`WHERE` keeps a row only when the condition is TRUE.** Rows where it is
> FALSE *or NULL* are dropped. NULL is not "sort of true" — for filtering
> purposes it behaves like a rejection, silently.

### IS NULL / IS NOT NULL

Because `= NULL` can never be TRUE, SQL provides dedicated predicates.
Business question: *which customers have no phone number on file?* (About 29%
of Nordkart customers don't — the SMS channel can't reach them.)

```sql
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE phone IS NULL
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────┬───────╮
│ customer_id │ first_name │ last_name │ phone │
╞═════════════╪════════════╪═══════════╪═══════╡
│           1 │ Hiro       │ Fisker    │       │
│           2 │ Tobias     │ Ek        │       │
│           4 │ Frida      │ Holm      │       │
│           5 │ Bjorn      │ Ahmed     │       │
│           7 │ Mikael     │ Karlsson  │       │
╰─────────────┴────────────┴───────────┴───────╯
```

(231 rows total.) And the SMS-reachable marketing audience — opted in *and*
phone on file:

```sql
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE marketing_opt_in = 1
  AND phone IS NOT NULL
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────┬──────────────╮
│ customer_id │ first_name │ last_name │    phone     │
╞═════════════╪════════════╪═══════════╪══════════════╡
│           3 │ Ulf        │ Hansen    │ +30 31429110 │
│           8 │ Priya      │ Tanaka    │ +37 31931511 │
│          10 │ Nora       │ Karlsson  │ +40 38538251 │
│          12 │ Wilma      │ Magnusson │ +32 16323852 │
│          14 │ Anders     │ Vik       │ +40 24972279 │
╰─────────────┴────────────┴───────────┴──────────────╯
```

(219 rows total.)

### NULL in AND / OR / NOT: the truth tables

NULL propagates through boolean operators, but not blindly — `AND` and `OR`
can sometimes decide *without* knowing the unknown value:

```sql
SELECT (NULL AND 0) AS null_and_false,
       (NULL AND 1) AS null_and_true,
       (NULL OR 0)  AS null_or_false,
       (NULL OR 1)  AS null_or_true,
       (NOT NULL)   AS not_null;
```

```text
╭────────────────┬───────────────┬───────────────┬──────────────┬──────────╮
│ null_and_false │ null_and_true │ null_or_false │ null_or_true │ not_null │
╞════════════════╪═══════════════╪═══════════════╪══════════════╪══════════╡
│              0 │               │               │            1 │          │
╰────────────────┴───────────────┴───────────────┴──────────────┴──────────╯
```

Read it as "unknown, but maybe decidable anyway":

| expression      | result | why |
|---|---|---|
| `NULL AND FALSE`| FALSE  | one FALSE sinks an AND regardless of the unknown |
| `NULL AND TRUE` | NULL   | outcome hinges on the unknown |
| `NULL OR FALSE` | NULL   | outcome hinges on the unknown |
| `NULL OR TRUE`  | TRUE   | one TRUE saves an OR regardless of the unknown |
| `NOT NULL`      | NULL   | the negation of unknown is still unknown |

The `NOT NULL` row is the sneaky one: negating a condition does **not** rescue
the NULL rows. If `phone LIKE '+49%'` is NULL (phone missing), then
`NOT (phone LIKE '+49%')` is *also* NULL — the row fails both the condition
and its negation. A `WHERE` clause and its negation do not split the table in
two; the NULL rows fall through the crack. That is the root cause of the
number-one pitfall below.

### IS: null-safe comparison

SQLite's `IS` operator compares like `=` but treats two NULLs as equal and
NULL-vs-value as not equal — it always yields TRUE or FALSE, never NULL:

```sql
SELECT NULL IS NULL AS a,
       5 IS NULL    AS b,
       NULL IS 5    AS c,
       5 IS 5       AS d;
```

```text
╭───┬───┬───┬───╮
│ a │ b │ c │ d │
╞═══╪═══╪═══╪═══╡
│ 1 │ 0 │ 0 │ 1 │
╰───┴───┴───┴───╯
```

> **PostgreSQL note:** PostgreSQL only allows `IS NULL` / `IS NOT NULL`
> literally; the general null-safe comparison is spelled
> `a IS NOT DISTINCT FROM b` (equal, NULL-safe) and `a IS DISTINCT FROM b`
> (not equal, NULL-safe). Same semantics, standard syntax, more typing.

### Seeing WHERE drop the NULL rows

The reviews table makes the three-way split tangible: ~35% of reviews are
rating-only, with NULL `review_text`. Ask for reviews mentioning "great":

```sql
SELECT review_id, rating, review_text
FROM reviews
WHERE review_text LIKE '%great%'
ORDER BY review_id
LIMIT 3;
```

```text
╭───────────┬────────┬───────────────────────────────────────────────╮
│ review_id │ rating │                  review_text                  │
╞═══════════╪════════╪═══════════════════════════════════════════════╡
│         1 │      5 │ Held up great on a week-long trip in Lapland. │
│         2 │      5 │ Held up great on a week-long trip in Lapland. │
│        10 │      4 │ Great value for the price point.              │
╰───────────┴────────┴───────────────────────────────────────────────╯
```

(429 rows total.) Now the "opposite" query:

```sql
SELECT review_id, rating, review_text
FROM reviews
WHERE review_text NOT LIKE '%great%'
ORDER BY review_id
LIMIT 3;
```

```text
╭───────────┬────────┬───────────────────────────────────────────────────────╮
│ review_id │ rating │                      review_text                      │
╞═══════════╪════════╪═══════════════════════════════════════════════════════╡
│         3 │      5 │ Perfect fit and fast delivery.                        │
│         4 │      5 │ Light, sturdy, and packs down small. Would buy again. │
│         6 │      4 │ Excellent quality, exceeded my expectations.          │
╰───────────┴────────┴───────────────────────────────────────────────────────╯
```

(1,751 rows total.) But `reviews` has **3,331** rows, and 429 + 1,751 = 2,180.
The missing 1,151 rows are the NULL-text reviews: for them, both
`LIKE '%great%'` and `NOT LIKE '%great%'` evaluate to NULL, so both queries
drop them. Whenever a condition and its negation must together cover every
row, you need a third bucket: `... OR review_text IS NULL`.

## COALESCE, NULLIF, IFNULL: handling NULL deliberately

**`COALESCE(a, b, c, ...)`** returns the first non-NULL argument. It is the
standard tool for fallbacks and display defaults. Business question: *for an
outreach list, give each customer's best contact — phone if we have it,
otherwise email:*

```sql
SELECT first_name || ' ' || last_name AS customer,
       COALESCE(phone, email, 'no contact on file') AS best_contact
FROM customers
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────────────────╮
│  customer   │      best_contact      │
╞═════════════╪════════════════════════╡
│ Hiro Fisker │ hiro.fisker@gmail.com  │
│ Tobias Ek   │ tobias.ek@fastmail.com │
│ Ulf Hansen  │ +30 31429110           │
│ Frida Holm  │ frida.holm@yahoo.com   │
│ Bjorn Ahmed │ bjorn.ahmed@icloud.com │
╰─────────────┴────────────────────────╯
```

(The third argument never fires here — `email` is NOT NULL — but defensive
final fallbacks cost nothing and save reports from blank cells.)

**`IFNULL(a, b)`** is SQLite's two-argument shorthand for the same thing:

```sql
SELECT review_id, rating,
       IFNULL(review_text, '(rating only)') AS review_display
FROM reviews
ORDER BY review_id
LIMIT 5;
```

```text
╭───────────┬────────┬───────────────────────────────────────────────────────╮
│ review_id │ rating │                    review_display                     │
╞═══════════╪════════╪═══════════════════════════════════════════════════════╡
│         1 │      5 │ Held up great on a week-long trip in Lapland.         │
│         2 │      5 │ Held up great on a week-long trip in Lapland.         │
│         3 │      5 │ Perfect fit and fast delivery.                        │
│         4 │      5 │ Light, sturdy, and packs down small. Would buy again. │
│         5 │      5 │ (rating only)                                         │
╰───────────┴────────┴───────────────────────────────────────────────────────╯
```

> **PostgreSQL note:** PostgreSQL has no `IFNULL` — use `COALESCE`, which is
> standard SQL and works everywhere. Habit tip: just always write `COALESCE`.

**`NULLIF(a, b)`** goes the other way: it returns NULL if `a = b`, otherwise
`a`. Its two killer uses are converting sentinel values (a `0` or `'N/A'` that
*means* "missing") into honest NULLs, and making division safe — `x / 0` is an
error in most databases, but `x / NULL` is just NULL. Business question:
*which products carry the highest markup (price ÷ cost)?*

```sql
SELECT name, unit_price, unit_cost,
       ROUND(unit_price / NULLIF(unit_cost, 0), 2) AS markup_ratio
FROM products
ORDER BY markup_ratio DESC
LIMIT 5;
```

```text
╭─────────────────────────┬────────────┬───────────┬──────────────╮
│          name           │ unit_price │ unit_cost │ markup_ratio │
╞═════════════════════════╪════════════╪═══════════╪══════════════╡
│ Core Rope 70m           │     147.33 │     61.89 │         2.38 │
│ Rescue Avalanche Beacon │     834.53 │    351.53 │         2.37 │
│ Flex Ski Poles          │     101.75 │     43.18 │         2.36 │
│ Fjell Quilt             │     205.85 │     87.47 │         2.35 │
│ Vandra Backpack 35L     │     273.31 │    116.49 │         2.35 │
╰─────────────────────────┴────────────┴───────────┴──────────────╯
```

No product here has a zero cost, but data changes; `NULLIF` turns a future
divide-by-zero crash into a NULL you can see and investigate. The pattern
`x / NULLIF(y, 0)` should be muscle memory.

## CASE: conditional values

`CASE` is SQL's if/else expression. It has two forms.

**Simple form** compares one expression against values — good for translating
codes. Business question: *what should the order-status page show customers?*

```sql
SELECT order_id, status,
       CASE status
         WHEN 'pending'   THEN 'Being processed'
         WHEN 'paid'      THEN 'Being processed'
         WHEN 'shipped'   THEN 'On its way'
         WHEN 'delivered' THEN 'Completed'
         ELSE 'Contact support'
       END AS customer_facing_status
FROM orders
ORDER BY order_id
LIMIT 5;
```

```text
╭──────────┬───────────┬────────────────────────╮
│ order_id │  status   │ customer_facing_status │
╞══════════╪═══════════╪════════════════════════╡
│        1 │ delivered │ Completed              │
│        2 │ cancelled │ Contact support        │
│        3 │ shipped   │ On its way             │
│        4 │ delivered │ Completed              │
│        5 │ delivered │ Completed              │
╰──────────┴───────────┴────────────────────────╯
```

**Searched form** evaluates arbitrary conditions top-to-bottom and takes the
**first** match — ideal for bucketing ranges. Because evaluation stops at the
first TRUE branch, each `WHEN` only needs an upper bound. Business question:
*band the active catalog by price:*

```sql
SELECT name, unit_price,
       CASE
         WHEN unit_price < 50  THEN 'budget'
         WHEN unit_price < 200 THEN 'mid-range'
         WHEN unit_price < 500 THEN 'premium'
         ELSE 'luxury'
       END AS price_band
FROM products
WHERE is_active = 1
ORDER BY unit_price DESC
LIMIT 5;
```

```text
╭─────────────────────────┬────────────┬────────────╮
│          name           │ unit_price │ price_band │
╞═════════════════════════╪════════════╪════════════╡
│ Drift Inflatable Kayak  │    1004.85 │ luxury     │
│ Fjord Sit-on-Top Kayak  │     934.86 │ luxury     │
│ Probe Airbag Pack       │     893.33 │ luxury     │
│ Rescue Avalanche Beacon │     834.53 │ luxury     │
│ Tele Touring Skis       │     775.98 │ luxury     │
╰─────────────────────────┴────────────┴────────────╯
```

Two rules worth tattooing somewhere: **a `CASE` without `ELSE` returns NULL**
when nothing matches (a frequent source of surprise NULLs), and the branches
are checked *in order*, so overlapping conditions resolve to the first one.

**`CASE` in `ORDER BY`** gives you custom sort orders. Alphabetically,
`paid < pending < shipped` — useless for an ops dashboard that wants
lifecycle order. Business question: *show the open order backlog in workflow
order, oldest first within each stage:*

```sql
SELECT order_id, status, ordered_at
FROM orders
WHERE status IN ('pending', 'paid', 'shipped')
ORDER BY
  CASE status
    WHEN 'pending' THEN 1
    WHEN 'paid'    THEN 2
    WHEN 'shipped' THEN 3
  END,
  ordered_at
LIMIT 8;
```

```text
╭──────────┬─────────┬─────────────────────╮
│ order_id │ status  │     ordered_at      │
╞══════════╪═════════╪═════════════════════╡
│     4365 │ pending │ 2026-07-12 13:42:52 │
│     1488 │ pending │ 2026-07-12 14:24:03 │
│      510 │ pending │ 2026-07-12 14:28:26 │
│      447 │ pending │ 2026-07-12 17:03:00 │
│     3787 │ pending │ 2026-07-12 17:57:57 │
│     1989 │ pending │ 2026-07-12 18:43:05 │
│     1596 │ pending │ 2026-07-12 18:51:38 │
│     4709 │ pending │ 2026-07-12 20:00:19 │
╰──────────┴─────────┴─────────────────────╯
```

(306 open orders total.)

**CASE and NULL** interact exactly as three-valued logic predicts — and the
simple form has a trap. `CASE x WHEN y` compares with `=`, so
`WHEN NULL` can never match:

```sql
SELECT CASE NULL WHEN NULL THEN 'matched' ELSE 'did not match' END AS simple_form,
       CASE WHEN NULL IS NULL THEN 'matched' ELSE 'did not match' END AS searched_form;
```

```text
╭───────────────┬───────────────╮
│  simple_form  │ searched_form │
╞═══════════════╪═══════════════╡
│ did not match │ matched       │
╰───────────────┴───────────────╯
```

Rule: to branch on NULL, always use the searched form with `IS NULL`.

## Filtering on dates

Nordkart stores timestamps as ISO-8601 TEXT: `YYYY-MM-DD HH:MM:SS`. This
format's superpower is that **lexicographic order equals chronological
order** — plain string comparison filters time correctly. Business question:
*what happened on 1 July 2026?*

```sql
SELECT order_id, ordered_at, status
FROM orders
WHERE ordered_at >= '2026-07-01'
  AND ordered_at <  '2026-07-02'
ORDER BY ordered_at;
```

```text
╭──────────┬─────────────────────┬───────────╮
│ order_id │     ordered_at      │  status   │
╞══════════╪═════════════════════╪═══════════╡
│      253 │ 2026-07-01 01:26:38 │ shipped   │
│     1614 │ 2026-07-01 02:40:38 │ cancelled │
│     5282 │ 2026-07-01 06:24:03 │ delivered │
│     4925 │ 2026-07-01 08:28:14 │ delivered │
│     1059 │ 2026-07-01 09:45:19 │ delivered │
│     1103 │ 2026-07-01 10:00:30 │ delivered │
│      345 │ 2026-07-01 10:53:33 │ delivered │
│     4772 │ 2026-07-01 12:18:00 │ shipped   │
│     3546 │ 2026-07-01 12:31:05 │ delivered │
│      180 │ 2026-07-01 13:27:35 │ delivered │
╰──────────┴─────────────────────┴───────────╯
... 22 rows total
```

Study the shape of that filter: `>= start AND < next_start`. This is the
**half-open range** `[start, next_start)`, and it is *the* professional idiom
for time filtering, for three reasons:

1. **No boundary loss.** Every timestamp on the last day — `23:59:59` and all
   — is strictly less than the next day's midnight. Nothing falls through.
2. **No calendar math.** "July 2026" is `>= '2026-07-01' AND < '2026-08-01'`.
   You never need to know whether a month has 30 or 31 days or whether
   February has 29.
3. **Perfect tiling.** Consecutive half-open windows share boundaries without
   overlapping: an order at exactly midnight lands in exactly one window.
   Daily, monthly, and yearly reports add up to the total, always.

### date() and strftime()

For extracting date parts, SQLite provides date functions that understand
ISO-8601 text. `date()` truncates to the day; `strftime()` formats with
`%`-codes (`%Y` year, `%m` month, `%d` day, `%H` hour...):

```sql
SELECT ordered_at,
       date(ordered_at)              AS order_date,
       strftime('%Y', ordered_at)    AS year,
       strftime('%Y-%m', ordered_at) AS year_month
FROM orders
ORDER BY order_id
LIMIT 3;
```

```text
╭─────────────────────┬────────────┬──────┬────────────╮
│     ordered_at      │ order_date │ year │ year_month │
╞═════════════════════╪════════════╪══════╪════════════╡
│ 2026-03-01 22:15:44 │ 2026-03-01 │ 2026 │ 2026-03    │
│ 2023-08-23 13:27:07 │ 2023-08-23 │ 2023 │ 2023-08    │
│ 2026-07-07 18:14:23 │ 2026-07-07 │ 2026 │ 2026-07    │
╰─────────────────────┴────────────┴──────┴────────────╯
```

`date()` also accepts **modifiers** that shift or snap a date — the building
blocks for "last 30 days" and "this month so far" style windows:

```sql
SELECT date('2026-07-14')                             AS as_of,
       date('2026-07-14', '-30 days')                 AS thirty_days_earlier,
       date('2026-07-14', 'start of month')           AS month_start,
       date('2026-07-14', 'start of year')            AS year_start,
       date('2026-07-14', '+1 month', 'start of month') AS next_month_start;
```

```text
╭────────────┬─────────────────────┬─────────────┬────────────┬──────────────────╮
│   as_of    │ thirty_days_earlier │ month_start │ year_start │ next_month_start │
╞════════════╪═════════════════════╪═════════════╪════════════╪══════════════════╡
│ 2026-07-14 │ 2026-06-14          │ 2026-07-01  │ 2026-01-01 │ 2026-08-01       │
╰────────────┴─────────────────────┴─────────────┴────────────┴──────────────────╯
```

(In real dashboards you'd write `date('now', ...)`; we pin a literal date here
so the output is reproducible.) Note `'+1 month', 'start of month'` — modifiers
apply left to right, and that pair computes exactly the exclusive upper bound a
half-open range wants.

`strftime()` enables cross-year seasonal questions that plain ranges can't
express. Business question: *marketing wants everything ever ordered in hiking
season (June–July), any year:*

```sql
SELECT order_id, ordered_at
FROM orders
WHERE strftime('%m', ordered_at) IN ('06', '07')
ORDER BY ordered_at
LIMIT 5;
```

```text
╭──────────┬─────────────────────╮
│ order_id │     ordered_at      │
╞══════════╪═════════════════════╡
│     3768 │ 2023-06-02 19:29:04 │
│     5154 │ 2023-06-03 23:22:43 │
│     5618 │ 2023-06-04 11:44:18 │
│     5998 │ 2023-06-09 10:12:44 │
│     3172 │ 2023-06-11 17:13:44 │
╰──────────┴─────────────────────╯
```

(1,550 rows total.) Note `strftime('%m', ...)` returns *text* (`'06'`, not
`6`), so compare against string literals. One caveat to file away: wrapping a
column in a function like this prevents the database from using an index on
that column — fine for ad-hoc analysis, a performance topic we treat properly
in Module 10. For contiguous windows, always prefer the plain half-open range:

```sql
SELECT order_id, ordered_at, status
FROM orders
WHERE ordered_at >= '2025-11-01'
  AND ordered_at <  '2026-01-01'
ORDER BY ordered_at DESC
LIMIT 5;
```

```text
╭──────────┬─────────────────────┬───────────╮
│ order_id │     ordered_at      │  status   │
╞══════════╪═════════════════════╪═══════════╡
│     3920 │ 2025-12-31 22:32:52 │ cancelled │
│     5472 │ 2025-12-31 21:26:33 │ delivered │
│     1071 │ 2025-12-31 19:59:44 │ delivered │
│     3810 │ 2025-12-31 19:32:19 │ delivered │
│     4926 │ 2025-12-31 18:53:44 │ delivered │
╰──────────┴─────────────────────┴───────────╯
```

(742 rows total — the Nov–Dec 2025 holiday window, and note the 22:32:52 order
on New Year's Eve is safely included.)

> **PostgreSQL note:** PostgreSQL has real `date`/`timestamp` types instead of
> ISO text, so you'd write `ordered_at >= DATE '2025-11-01'`, extract parts
> with `EXTRACT(MONTH FROM ordered_at)` or `date_trunc('month', ordered_at)`,
> and do arithmetic with intervals (`now() - INTERVAL '30 days'`). The
> **half-open range idiom is identical** — it is the professional habit that
> transfers across every database and every date representation.

## Pitfalls

### Pitfall 1: `!=` silently drops NULL rows

The scenario: customer 3 (phone `+30 31429110`) asked to be excluded from a
call campaign. A colleague writes "everyone whose phone isn't that number"
and, testing on the first five customers, gets a shock:

```sql
-- BAD: meant "exclude customer 3's number", but NULL phones vanish too
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE customer_id <= 5
  AND phone != '+30 31429110';
```

```text
```

**Zero rows.** Customer 3 is correctly excluded (`'+30 ...' != '+30 ...'` is
FALSE), but customers 1, 2, 4, and 5 all have NULL phones, so for them
`phone != '+30 31429110'` is NULL — and `WHERE` drops NULL just like FALSE.
The exclusion of one customer nuked the whole list. The fix — decide
explicitly what NULL should mean here (a missing phone certainly isn't the
excluded number, so keep those rows):

```sql
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE customer_id <= 5
  AND (phone IS NULL OR phone != '+30 31429110');
```

```text
╭─────────────┬────────────┬───────────┬───────╮
│ customer_id │ first_name │ last_name │ phone │
╞═════════════╪════════════╪═══════════╪═══════╡
│           1 │ Hiro       │ Fisker    │       │
│           2 │ Tobias     │ Ek        │       │
│           4 │ Frida      │ Holm      │       │
│           5 │ Bjorn      │ Ahmed     │       │
╰─────────────┴────────────┴───────────┴───────╯
```

(In SQLite, `phone IS NOT '+30 31429110'` says the same thing in one
null-safe operator; in PostgreSQL, `phone IS DISTINCT FROM '+30 31429110'`.)

The same bug hits every negative predicate — `NOT LIKE`, `NOT IN`,
`<>` — at scale. "Send the postal mailer to everyone without a German (+49)
phone number":

```sql
-- BAD: excludes the 231 customers with no phone at all from a postal mailing
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE phone NOT LIKE '+49%'
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────┬──────────────╮
│ customer_id │ first_name │ last_name │    phone     │
╞═════════════╪════════════╪═══════════╪══════════════╡
│           3 │ Ulf        │ Hansen    │ +30 31429110 │
│           6 │ Mats       │ Sjoberg   │ +39 20709497 │
│           8 │ Priya      │ Tanaka    │ +37 31931511 │
│           9 │ Hiro       │ Wall      │ +31 40742311 │
│          10 │ Nora       │ Karlsson  │ +40 38538251 │
╰─────────────┴────────────┴───────────┴──────────────╯
... 534 rows total
```

Look at the ids: 1, 2, 4, 5, 7 are simply *gone* — those customers have no
phone, which is exactly why the postal mailer should reach them. 534 rows
instead of the correct 765. The fix:

```sql
SELECT customer_id, first_name, last_name, phone
FROM customers
WHERE phone IS NULL
   OR phone NOT LIKE '+49%'
ORDER BY customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬───────────┬──────────────╮
│ customer_id │ first_name │ last_name │    phone     │
╞═════════════╪════════════╪═══════════╪══════════════╡
│           1 │ Hiro       │ Fisker    │              │
│           2 │ Tobias     │ Ek        │              │
│           3 │ Ulf        │ Hansen    │ +30 31429110 │
│           4 │ Frida      │ Holm      │              │
│           5 │ Bjorn      │ Ahmed     │              │
╰─────────────┴────────────┴───────────┴──────────────╯
... 765 rows total
```

The habit to build: **every time you write a negative condition on a nullable
column, ask "what should happen to the NULL rows?" and encode the answer
explicitly.**

### Pitfall 2: `BETWEEN` on timestamps loses the last day

"All orders placed in 2025" — the intuitive version:

```sql
-- BAD: "orders in 2025" — silently loses nearly all of December 31
SELECT order_id, ordered_at
FROM orders
WHERE ordered_at BETWEEN '2025-01-01' AND '2025-12-31'
ORDER BY ordered_at DESC
LIMIT 3;
```

```text
╭──────────┬─────────────────────╮
│ order_id │     ordered_at      │
╞══════════╪═════════════════════╡
│     1543 │ 2025-12-30 22:34:02 │
│     1519 │ 2025-12-30 21:09:16 │
│     1389 │ 2025-12-30 21:06:55 │
╰──────────┴─────────────────────╯
```

The latest "2025" order is on December *30*. `BETWEEN` is inclusive, but the
upper bound is the string `'2025-12-31'` — midnight — and every actual order
that day (`'2025-12-31 01:56:42'` and later) sorts *after* it, so all 23
New Year's Eve orders are excluded. The query returns 2,113 rows instead of
2,136; an annual revenue report built on it is quietly wrong, on one of the
busiest days of the year. Patching to `AND '2025-12-31 23:59:59'` "works"
until someone stores sub-second precision. The professional fix is the
half-open range:

```sql
SELECT order_id, ordered_at
FROM orders
WHERE ordered_at >= '2025-01-01'
  AND ordered_at <  '2026-01-01'
ORDER BY ordered_at DESC
LIMIT 3;
```

```text
╭──────────┬─────────────────────╮
│ order_id │     ordered_at      │
╞══════════╪═════════════════════╡
│     3920 │ 2025-12-31 22:32:52 │
│     5472 │ 2025-12-31 21:26:33 │
│     1071 │ 2025-12-31 19:59:44 │
╰──────────┴─────────────────────╯
```

December 31 is back (2,136 rows total). Rule of thumb: `BETWEEN` is fine for
prices and quantities; for timestamps, **always** `>= start AND < next_start`.

### Pitfall 3: OR without parentheses

Marketing asks for "customers in Sweden or Norway who opted in". Typed
straight from English:

```sql
-- BAD: AND binds tighter than OR — this is Sweden-anyone OR (Norway AND opted-in)
SELECT customer_id, first_name, country, marketing_opt_in
FROM customers
WHERE country = 'Sweden' OR country = 'Norway' AND marketing_opt_in = 1
ORDER BY marketing_opt_in, customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬─────────┬──────────────────╮
│ customer_id │ first_name │ country │ marketing_opt_in │
╞═════════════╪════════════╪═════════╪══════════════════╡
│           4 │ Frida      │ Sweden  │                0 │
│           9 │ Hiro       │ Sweden  │                0 │
│          21 │ Isak       │ Sweden  │                0 │
│          25 │ Elias      │ Sweden  │                0 │
│          26 │ Dag        │ Sweden  │                0 │
╰─────────────┴────────────┴─────────┴──────────────────╯
```

Opted-*out* Swedes, right at the top — because the query parsed as
`country = 'Sweden' OR (country = 'Norway' AND marketing_opt_in = 1)`:
*every* Swede qualifies regardless of consent. 218 rows instead of the
correct 106, and emailing them is a GDPR incident, not just a wrong number.
Parentheses restore the intended grouping:

```sql
SELECT customer_id, first_name, country, marketing_opt_in
FROM customers
WHERE (country = 'Sweden' OR country = 'Norway')
  AND marketing_opt_in = 1
ORDER BY marketing_opt_in, customer_id
LIMIT 5;
```

```text
╭─────────────┬────────────┬─────────┬──────────────────╮
│ customer_id │ first_name │ country │ marketing_opt_in │
╞═════════════╪════════════╪═════════╪══════════════════╡
│          10 │ Nora       │ Sweden  │                1 │
│          12 │ Wilma      │ Sweden  │                1 │
│          40 │ Freja      │ Sweden  │                1 │
│          44 │ Linnea     │ Norway  │                1 │
│          81 │ Leif       │ Sweden  │                1 │
╰─────────────┴────────────┴─────────┴──────────────────╯
```

(106 rows total.) Even better here: `country IN ('Sweden', 'Norway') AND
marketing_opt_in = 1` — `IN` removes the `OR` and the trap with it.

### Pitfall 4 (a flag for Module 4): NOT IN meets NULL

`NOT IN` looks like a plain complement, and with a hand-written list of
non-NULL literals it is. But watch what a single NULL in the list does:

```sql
SELECT 2 NOT IN (1, 3)    AS clean_list,
       2 NOT IN (1, NULL) AS list_with_null;
```

```text
╭────────────┬────────────────╮
│ clean_list │ list_with_null │
╞════════════╪════════════════╡
│          1 │                │
╰────────────┴────────────────╯
```

`2 NOT IN (1, NULL)` is NULL — "2 is not 1, and whether it equals the unknown
value... is unknown" — so a `WHERE` would drop the row. One NULL poisons the
entire `NOT IN`, returning **zero rows** no matter the data. This becomes a
genuinely dangerous bug in Module 4, when the list comes from a subquery that
can silently contain NULLs. For now: `NOT IN` with literal lists you control —
fine; the full story and the `NOT EXISTS` antidote — Module 4.

## Exercises

Answer each with a single query. No answers here — solutions (with
explanations and common wrong turns) are in
`solutions/02-filtering-and-null.md`. Try honestly first.

**Warm-up**

1. **Impulse rack.** Merchandising wants the full list of *active* products
   priced under 25, cheapest first. Show name and price.
2. **Copenhagen pop-up.** Nordkart is hosting a pop-up store event for
   customers living in Copenhagen or Aarhus. List their full name (one
   column) and city, alphabetized by last name then first name.
3. **Tent finder.** A support agent needs every product whose name contains
   "tent", most expensive first. Show name and price. (Would your query still
   work if you ran it on PostgreSQL? Say why or why not in a comment.)

**Core**

4. **SMS launch list.** For a product launch, list `customer_id`, full name,
   and phone of every customer in Sweden, Norway, Denmark, or Finland who has
   opted in to marketing *and* has a phone number on file, ordered by
   `customer_id`. Show the first 10.
5. **"Give us your number" campaign.** The CRM team wants to email customers
   who opted in to marketing but have no phone on file, newest accounts
   first. Show email and `created_at`; first 10.
6. **Holiday trading report rows.** List `order_id`, `ordered_at`, and
   `status` for all orders placed in November–December 2025 that were *not*
   cancelled, newest first (first 10). Use a range that provably keeps
   New Year's Eve orders... wait — should Dec 31 orders be in a Nov–Dec
   window? Decide, and make your boundaries exact.
7. **Price bands.** Tag every *active* product with a band: `budget`
   (under 50), `mid-range` (50 to under 200), `premium` (200 to under 500),
   `luxury` (500 and up). Show name, price, and band for the 10 most
   expensive.
8. **Review triage.** Customer support wants the 10 most recent reviews with
   a rating of 2 or less **that actually contain text** (rating-only reviews
   can't be replied to). Show `review_id`, rating, and the text.
9. **Backlog board.** Ops wants all open orders (`pending`, `paid`,
   `shipped`) sorted by lifecycle stage — pending first, then paid, then
   shipped — and oldest first within each stage. Show `order_id`, status,
   `ordered_at`; first 10.

**Challenge**

10. **Power-buyer recency.** As of `2026-07-15`, label each of customer 684's
    non-cancelled orders `last 30 days`, `last 90 days`, or `older`. Compute
    the cutoffs with `date()` modifiers rather than hard-coding them. Show
    `order_id`, `ordered_at`, and the bucket for the 12 most recent.
11. **Contact channel routing.** For each customer produce a
    `contact_channel` column: `sms` if they opted in and have a phone,
    `email` if they opted in but have no phone, `do not contact` otherwise.
    Show `customer_id`, full name, and channel for the first 10 customers by
    id. (Careful: one of the branches must reason about NULL.)
12. **New Year's Eve staffing.** Ops is planning holiday staffing and wants
    every order ever placed on December 31 — *any* year. Show `order_id`,
    `ordered_at`, `status`, newest first, first 10. (A plain range can't say
    "Dec 31 of every year"...)

## Key takeaways

- `WHERE` keeps a row **only if the condition is TRUE** — FALSE and NULL both
  drop it. A condition and its negation do *not* partition a table when NULLs
  exist.
- Precedence: `NOT` > `AND` > `OR`. Mixing `AND`/`OR`? **Parenthesize.**
  Better yet, replace `OR`-chains on one column with `IN (...)`.
- `x BETWEEN lo AND hi` = `x >= lo AND x <= hi`, **both ends inclusive**.
  Fine for numbers; never for timestamps.
- Time filtering: **half-open ranges** — `col >= 'start' AND col <
  'next_start'`. No lost boundary rows, no calendar math, windows tile
  perfectly. ISO-8601 text compares correctly as strings.
- `LIKE`: `%` = any run, `_` = one char, `ESCAPE '\'` to match literal
  wildcards. SQLite `LIKE` is case-insensitive (ASCII); PostgreSQL's is
  case-sensitive — use `ILIKE` or `lower()` there.
- `NULL` = unknown. `NULL = NULL` → NULL. Test with `IS NULL` /
  `IS NOT NULL`; null-safe compare is `IS` (SQLite) / `IS DISTINCT FROM`
  (PostgreSQL).
- Truth tables: `NULL AND FALSE` → FALSE; `NULL OR TRUE` → TRUE; everything
  else involving NULL stays NULL, including `NOT NULL`.
- `COALESCE(a, b, ...)` → first non-NULL (portable; prefer over `IFNULL`).
  `NULLIF(a, b)` → NULL if equal — sentinel cleanup and the div-by-zero guard
  `x / NULLIF(y, 0)`.
- `CASE`: simple form compares with `=` (so `WHEN NULL` never matches);
  searched form takes the **first** TRUE branch; missing `ELSE` yields NULL.
  Works anywhere an expression does — including `ORDER BY`.
- Negative predicates (`!=`, `NOT LIKE`, `NOT IN`) on nullable columns:
  decide explicitly what NULL rows should do, usually via
  `col IS NULL OR ...`.
