# Module 7 Solutions — Data Modeling

All queries run against `scratch.db` **after** working through the module top-to-bottom (in particular, the star schema from section 7.9 must exist). Design exercises get reference answers — treat them as *a* good design with reasoning, not the only one; your design is correct if it enforces the same rules and avoids the same anomalies.

## Warm-up

### Exercise 1 — Cardinality audit

- **customers ↔ addresses — 1:N.** One customer has many addresses; an address belongs to exactly one customer. The FK (`customer_id`) lives on `addresses`, the *many* side — it must, because a FK column holds a single value, so the row that points is always the row that can have only one partner.
- **orders ↔ shipments — 1:N as modeled** (`shipments.order_id` FK), though today's data uses it as 1:0..1. Putting the FK on `shipments` keeps the door open for split parcels without a schema change.
- **products ↔ suppliers — N:1.** Many products per supplier, one supplier per product, so the FK (`supplier_id`) lives on `products`.

One combined verification (each subquery checks the "many" side of one pair):

```sql
SELECT
    (SELECT MAX(n) FROM (SELECT COUNT(*) AS n FROM addresses GROUP BY customer_id))
        AS max_addresses_per_customer,
    (SELECT MAX(n) FROM (SELECT COUNT(*) AS n FROM shipments GROUP BY order_id))
        AS max_shipments_per_order,
    (SELECT MAX(n) FROM (SELECT COUNT(*) AS n FROM products GROUP BY supplier_id))
        AS max_products_per_supplier;
```

```text
╭────────────────────────────┬─────────────────────────┬───────────────────────────╮
│ max_addresses_per_customer │ max_shipments_per_order │ max_products_per_supplier │
╞════════════════════════════╪═════════════════════════╪═══════════════════════════╡
│                          3 │                       1 │                        14 │
╰────────────────────────────┴─────────────────────────┴───────────────────────────╯
```

Customers reach 3 addresses and suppliers 14 products (genuinely "many"); shipments max out at 1 per order — the schema *allows* more, the business hasn't needed it yet. That gap between modeled and observed cardinality is worth writing down when you document a schema.

### Exercise 2 — Fulfilment sanity check

```sql
SELECT COUNT(*) AS orders_with_multiple_shipments
FROM (
    SELECT order_id
    FROM shipments
    GROUP BY order_id
    HAVING COUNT(*) > 1
);
```

```text
╭────────────────────────────────╮
│ orders_with_multiple_shipments │
╞════════════════════════════════╡
│                              0 │
╰────────────────────────────────╯
```

```sql
SELECT o.status, COUNT(*) AS orders_without_shipment
FROM orders AS o
LEFT JOIN shipments AS s ON s.order_id = o.order_id
WHERE s.shipment_id IS NULL
GROUP BY o.status
ORDER BY orders_without_shipment DESC;
```

```text
╭───────────┬─────────────────────────╮
│  status   │ orders_without_shipment │
╞═══════════╪═════════════════════════╡
│ cancelled │                     315 │
│ paid      │                      90 │
│ pending   │                      63 │
╰───────────┴─────────────────────────╯
```

Logistics' claim is false today: no order has two shipment rows. The missing-shipment breakdown makes perfect business sense — cancelled orders never ship, and `pending`/`paid` orders haven't shipped *yet*. Every `shipped`, `delivered`, and `returned` order has a shipment (5,532 = 153 + 5,207 + 172). The anti-join (`LEFT JOIN ... IS NULL`) is the Module 4 pattern for "rows with no match".

### Exercise 3 — A promise as a query

```sql
SELECT COUNT(*) AS violators
FROM (
    SELECT customer_id
    FROM addresses
    GROUP BY customer_id
    HAVING SUM(is_default) <> 1
);
```

```text
╭───────────╮
│ violators │
╞═══════════╡
│         0 │
╰───────────╯
```

`SUM(is_default)` per customer counts default addresses (0/1 flags sum cleanly); any value other than 1 — zero defaults or several — is a violation. Drop the outer `COUNT(*)` wrapper to *list* violators instead (it returns no rows). Note this rule spans multiple rows, so a plain column `CHECK` can't enforce it — it lives in application logic or triggers, which is exactly why "promise as a query" checks like this belong in your data-test suite (Module 12).

### Exercise 4 — Natural key debate

Two reasons for the surrogate `supplier_id`:

1. **Supplier names change** — rebrands, acquisitions, legal-form changes ("... GmbH" → "... AG"). If `name` were the PK, every `products` row referencing it would need a coordinated cascading update; with a surrogate, renaming is a one-column update in one row.
2. **Size and copies** — the PK is duplicated into every referencing row and every index on it. `'Basecamp Wholesale BV'` is ~20 bytes against 8 for an integer, and joins on long strings are slower.

The event that hurts: a rebrand of a large supplier. How many referencing rows would a name-keyed schema have to update atomically?

```sql
SELECT s.name, COUNT(p.product_id) AS product_rows_referencing_it
FROM suppliers AS s
JOIN products AS p ON p.supplier_id = s.supplier_id
GROUP BY s.name
ORDER BY product_rows_referencing_it DESC
LIMIT 3;
```

```text
╭───────────────────────┬─────────────────────────────╮
│         name          │ product_rows_referencing_it │
╞═══════════════════════╪═════════════════════════════╡
│ Basecamp Wholesale BV │                          14 │
│ Tundra Textiles Oy    │                          13 │
│ Glacier Goods AG      │                          13 │
╰───────────────────────┴─────────────────────────────╯
```

Fourteen rows here; millions in a real catalog — and any table you forgot (exports, logs, archives) now silently disagrees. Keep `name` as `UNIQUE` (the business rule survives), key on the surrogate.

## Core

### Exercise 5 — Gift cards

Two entities: the card (one row per card sold) and its redemptions (one row per use — a card redeems *many* times, across *many* orders, so redemptions are a separate 1:N table, not columns on the card).

```sql
CREATE TABLE gift_cards (
    gift_card_id  INTEGER PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,
    initial_value REAL NOT NULL CHECK (initial_value > 0),
    purchased_by  INTEGER REFERENCES customers(customer_id),
    order_id      INTEGER REFERENCES orders(order_id),
    issued_at     TEXT NOT NULL,
    expires_at    TEXT
);
CREATE TABLE gift_card_redemptions (
    redemption_id INTEGER PRIMARY KEY,
    gift_card_id  INTEGER NOT NULL REFERENCES gift_cards(gift_card_id),
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    amount        REAL NOT NULL CHECK (amount > 0),
    redeemed_at   TEXT NOT NULL
);
INSERT INTO gift_cards (code, initial_value, purchased_by, issued_at)
VALUES ('NKGC-A1B2C3', 100.0, 105, '2026-06-01 09:00:00');
INSERT INTO gift_card_redemptions (gift_card_id, order_id, amount, redeemed_at) VALUES
    (1, 3,  62.50, '2026-07-07 10:00:00'),
    (1, 10, 20.00, '2026-07-12 15:30:00');
SELECT
    g.code,
    g.initial_value,
    g.initial_value - COALESCE(SUM(r.amount), 0) AS balance
FROM gift_cards AS g
LEFT JOIN gift_card_redemptions AS r ON r.gift_card_id = g.gift_card_id
GROUP BY g.gift_card_id;
```

```text
╭─────────────┬───────────────┬─────────╮
│    code     │ initial_value │ balance │
╞═════════════╪═══════════════╪═════════╡
│ NKGC-A1B2C3 │         100.0 │    17.5 │
╰─────────────┴───────────────┴─────────╯
```

Design decisions and reasoning:

- **Balance is derived, not stored.** `initial_value` is immutable-once-written (a snapshot, like `order_items.unit_price`); redemptions are an append-only event log. `initial_value - SUM(redemptions)` is therefore always correct. A stored `balance` column is Pitfall 3 on a payment product: any code path that inserts a redemption but forgets the balance update creates free money (or steals it). If reads must be fast, cache the balance *with a refresh contract* — but the log stays the source of truth.
- `code` is the natural key customers type in — `UNIQUE`, but the surrogate `gift_card_id` does the joining (codes get reissued/reformatted; exercise 4's logic again).
- `purchased_by` and `order_id` are nullable: cards sold at retail or granted by support have neither. The FK columns document the relationship when it exists.
- A real system adds `CHECK`/application logic so redemptions never exceed the balance — that's a multi-row rule, enforced in a transaction (Module 9).

**Common wrong approach:** `gift_cards.remaining_balance REAL` updated on every use — the stored-derived-value trap; it *will* drift from the redemption log, and you won't know which one lies.

### Exercise 6 — Product bundles

Bundle ↔ component is **M:N** (a bundle has many components; a product can appear in many bundles), so it's a junction table — self-referencing into `products`, with `quantity` as relationship payload. The bundle itself is an ordinary product row, which is what keeps the rest of the schema working untouched.

```sql
CREATE TABLE bundle_components (
    bundle_product_id    INTEGER NOT NULL REFERENCES products(product_id),
    component_product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity             INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (bundle_product_id, component_product_id),
    CHECK (bundle_product_id <> component_product_id)
);
INSERT INTO products (product_id, sku, name, category_id, supplier_id,
                      unit_price, unit_cost, is_active, introduced_at)
VALUES (9001, 'NK-BND-9001', 'Weekend Camping Kit', 2, 1,
        799.0, 480.0, 1, '2026-07-15');
INSERT INTO bundle_components (bundle_product_id, component_product_id, quantity) VALUES
    (9001, 11,  1),
    (9001, 338, 1),
    (9001, 9,   2);
SELECT
    p.name                     AS component,
    bc.quantity,
    p.unit_price               AS sold_separately,
    bc.quantity * p.unit_price AS separate_total
FROM bundle_components AS bc
JOIN products AS p ON p.product_id = bc.component_product_id
WHERE bc.bundle_product_id = 9001;
```

```text
╭─────────────────────┬──────────┬─────────────────┬────────────────╮
│      component      │ quantity │ sold_separately │ separate_total │
╞═════════════════════╪══════════╪═════════════════╪════════════════╡
│ Fjell Quilt         │        2 │          205.85 │          411.7 │
│ Nordic Tunnel Tent  │        1 │           698.9 │          698.9 │
│ Vandra Backpack 70L │        1 │            86.5 │           86.5 │
╰─────────────────────┴──────────┴─────────────────┴────────────────╯
```

No product data is duplicated — components are *references*, and the query shows the bundle (799.00) undercuts the separate total (1,197.10), which marketing will like. Because the bundle is a `products` row, `order_items` can reference it directly and the **`unit_price` snapshot keeps working unchanged**: the line freezes the bundle's agreed price at checkout. What the snapshot does *not* capture is the component breakdown at order time — if the kit's contents change next season, historical orders can't be exploded accurately for inventory. If that matters, snapshot the components too (an `order_item_components` table written at checkout — same immutable-once-written principle).

The `CHECK (bundle_product_id <> component_product_id)` blocks direct self-containment; it can't block cycles through an intermediate bundle (A contains B contains A) — that needs application logic or a recursive-CTE assertion (Module 5 gives you the tool).

### Exercise 7 — Customer settings

```sql
CREATE TABLE customer_settings (
    customer_id          INTEGER PRIMARY KEY REFERENCES customers(customer_id),
    newsletter_frequency TEXT NOT NULL DEFAULT 'weekly'
                         CHECK (newsletter_frequency IN ('daily', 'weekly', 'monthly', 'never')),
    preferred_language   TEXT NOT NULL DEFAULT 'en',
    dark_mode            INTEGER NOT NULL DEFAULT 0 CHECK (dark_mode IN (0, 1))
);
INSERT INTO customer_settings (customer_id, newsletter_frequency, preferred_language)
VALUES (105, 'monthly', 'sv');
SELECT * FROM customer_settings;
```

```text
╭─────────────┬──────────────────────┬────────────────────┬───────────╮
│ customer_id │ newsletter_frequency │ preferred_language │ dark_mode │
╞═════════════╪══════════════════════╪════════════════════╪═══════════╡
│         105 │ monthly              │ sv                 │         0 │
╰─────────────┴──────────────────────┴────────────────────┴───────────╯
```

The one-row-per-customer rule is enforced **structurally**: `customer_id` is simultaneously the PK (so at most one row) and the FK (so only real customers) — the 1:0..1 pattern from section 7.11. Justification for the separate table: most customers never customize, so these columns on `customers` would be a wide strip of defaults/NULLs touched by unrelated code, whereas here *absence of a row cleanly means "all defaults"* (read with `LEFT JOIN` + `COALESCE`); and the settings group grows fast — new preferences land in this table without ever migrating the hot, heavily-referenced `customers` table.

**Common wrong approach:** a surrogate `settings_id` PK plus `customer_id UNIQUE` — not wrong, but the extra key buys nothing; when the FK *is* the identity, let it be the PK.

### Exercise 8 — Category league table

```sql
SELECT
    p.parent_category,
    ROUND(SUM(f.item_revenue), 2) AS gross_revenue
FROM fact_order_items AS f
JOIN dim_date    AS d ON d.date_key   = f.date_key
JOIN dim_product AS p ON p.product_id = f.product_id
WHERE f.order_status <> 'cancelled'
  AND d.year = 2024
GROUP BY p.parent_category
ORDER BY gross_revenue DESC
LIMIT 5;
```

```text
╭─────────────────┬───────────────╮
│ parent_category │ gross_revenue │
╞═════════════════╪═══════════════╡
│ Winter Sports   │     128797.56 │
│ Camping         │     123465.54 │
│ Water Sports    │      79513.82 │
│ Hiking          │      59311.46 │
│ Climbing        │      43474.66 │
╰─────────────────┴───────────────╯
```

The canonical gross-revenue definition excludes cancelled orders — hence `order_status <> 'cancelled'` (returned orders *stay in* gross). Note how the star pays off: `parent_category` is a plain column, no category self-join; the year is a dimension attribute, no `strftime`; `item_revenue` is precomputed with the canonical formula. Five parent categories appear because Apparel ranks sixth — `LIMIT 5` genuinely cut something.

**Common wrong approach:** filtering `WHERE p.is_active = 1` "to be tidy" — discontinued products still earned 2024 revenue; dimension attributes describe *today's* catalog state, and filtering facts by them rewrites history.

### Exercise 9 — Normalize the returns spreadsheet

Diagnosis first:

- **1NF violation:** `items_returned` is a repeating group in a string (`'NK-02-0011 x1; NK-05-0338 x2'`) — the M:N between a return and products, crammed into a column (Pitfall 2).
- **Functional dependencies:** `return_id → order_id, returned_at, carrier_name, warehouse_code`; `carrier_name → carrier_phone`; `warehouse_code → warehouse_city` (two transitive dependencies); `order_id → customer_email` and `customer_email → customer_name` — customer facts don't belong on a return at all, they're reachable through `orders` → `customers`, which Nordkart already has.
- **Concrete anomaly:** a warehouse moving from Malmö to Lund requires updating every historical return row that mentions the warehouse (update anomaly); miss some and the sheet claims the warehouse is in two cities. Also `refund_total` is derived from the per-item refunds and will drift the first time someone edits an item line without recomputing it.

The 3NF decomposition — customer columns dropped entirely (reuse `orders`/`customers`), one table per remaining entity, a junction table for the repeating group, and the derived total not stored:

```sql
CREATE TABLE carriers (
    carrier_name  TEXT PRIMARY KEY,
    support_phone TEXT
);
CREATE TABLE warehouses (
    warehouse_code TEXT PRIMARY KEY,
    city           TEXT NOT NULL
);
CREATE TABLE returns (
    return_id      INTEGER PRIMARY KEY,
    order_id       INTEGER NOT NULL REFERENCES orders(order_id),
    returned_at    TEXT NOT NULL,
    carrier_name   TEXT NOT NULL REFERENCES carriers(carrier_name),
    warehouse_code TEXT NOT NULL REFERENCES warehouses(warehouse_code)
);
CREATE TABLE return_items (
    return_id     INTEGER NOT NULL REFERENCES returns(return_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    refund_amount REAL NOT NULL CHECK (refund_amount >= 0),
    PRIMARY KEY (return_id, product_id)
);
SELECT name FROM sqlite_schema
WHERE type = 'table' AND name IN ('carriers', 'warehouses', 'returns', 'return_items')
ORDER BY name;
```

```text
╭──────────────╮
│     name     │
╞══════════════╡
│ carriers     │
│ return_items │
│ returns      │
│ warehouses   │
╰──────────────╯
```

Notes: `refund_amount` per item *is* stored — it's an agreed, immutable-once-written event fact (the snapshot pattern), while `refund_total` is `SUM(refund_amount)` at query time. I used natural keys for `carriers`/`warehouses` since codes/names are the given identifiers; surrogates would also be defensible (exercise 4's tradeoffs). SKUs from the sheet map to `product_id` FKs during load. In a fuller design you'd also `CHECK` that returned items actually appear on the referenced order — a multi-table rule for application logic or the load process (Module 9's staging patterns).

## Challenge

### Exercise 10 — Slow seller, honest zeros

```sql
WITH sales AS (
    SELECT
        d.month,
        SUM(f.quantity)     AS units,
        SUM(f.item_revenue) AS gross
    FROM fact_order_items AS f
    JOIN dim_date    AS d ON d.date_key   = f.date_key
    JOIN dim_product AS p ON p.product_id = f.product_id
    WHERE p.product_name = 'Vandra Backpack 70L'
      AND f.order_status <> 'cancelled'
      AND d.year = 2024
    GROUP BY d.month
),
months AS (
    SELECT DISTINCT month FROM dim_date WHERE year = 2024
)
SELECT
    m.month,
    COALESCE(s.units, 0)           AS units_sold,
    ROUND(COALESCE(s.gross, 0), 2) AS gross_revenue
FROM months AS m
LEFT JOIN sales AS s ON s.month = m.month
ORDER BY m.month;
```

```text
╭───────┬────────────┬───────────────╮
│ month │ units_sold │ gross_revenue │
╞═══════╪════════════╪═══════════════╡
│     1 │          1 │         64.95 │
│     2 │          0 │           0.0 │
│     3 │          2 │         129.9 │
│     4 │          0 │           0.0 │
│     5 │          4 │         286.1 │
│     6 │          3 │        220.08 │
│     7 │          1 │         73.36 │
│     8 │          4 │        289.77 │
│     9 │          1 │         62.36 │
│    10 │          1 │         66.02 │
│    11 │          5 │        375.22 │
│    12 │          4 │        324.71 │
╰───────┴────────────┴───────────────╯
```

February and April show honest zeros. The trick: aggregate the fact table first (`sales`), then `LEFT JOIN` it *onto* a complete month list built from `dim_date` — the dimension supplies rows the facts don't have. This "date spine" pattern returns, generalized, in Module 11.

**Common wrong approach:** `LEFT JOIN` from `dim_date` straight into the fact table and filter products in the `WHERE` clause — the product filter on the right table's columns turns the outer join back into an inner one (the Module 4 pitfall), and the zero months vanish. Filtering inside a pre-aggregated CTE (or in the join's `ON` clause) avoids it.

### Exercise 11 — To snapshot or not

**Yes — snapshot it.** Apply the 7.7 test: "what this line's stock cost us" is a fact about the moment of sale, frozen at write time, exactly like the agreed price. Without it, margin reports join to `products.unit_cost` — *today's* cost — and silently rewrite history every time a supplier reprices: last year's margins change retroactively, which no finance team will accept. (The alternative — a `cost_history` table plus point-in-time joins, like `price_history` — is also correct but makes every margin query pay the complexity; Module 11 shows that join.)

The catch is the backfill. Add the column and look:

```sql
ALTER TABLE order_items ADD COLUMN unit_cost REAL;
SELECT COUNT(*) AS lines_with_unknown_historical_cost
FROM order_items
WHERE unit_cost IS NULL;
```

```text
╭────────────────────────────────────╮
│ lines_with_unknown_historical_cost │
╞════════════════════════════════════╡
│                              13475 │
╰────────────────────────────────────╯
```

All 13,475 historical lines have unknown true cost, because *no cost history was ever recorded* — a snapshot only captures data from its own go-live onward. An honest backfill can: (a) leave history NULL and report margins only from the cutover date, or (b) fill from current `products.unit_cost` **and mark it estimated** (e.g. a `cost_is_estimated` flag). What it cannot do is recover facts nobody wrote down. The dishonest backfill — silently copying current costs in — produces confident, wrong historical margins, which is worse than no answer. General lesson: decide what to snapshot *early*; the decision is cheap on day one and impossible to retrofit.

### Exercise 12 — dim_customer

```sql
CREATE TABLE dim_customer AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.country,
    c.city,
    c.marketing_opt_in,
    DATE(c.created_at) AS signup_date
FROM customers AS c;
SELECT COUNT(*) AS customers FROM dim_customer;
```

```text
╭───────────╮
│ customers │
╞═══════════╡
│       800 │
╰───────────╯
```

800 rows — all customers, including the 125 who never ordered (a dimension describes entities, not activity; the never-buyers are exactly who a conversion analysis needs). What's in: the stable surrogate key the fact table already carries, plus descriptive attributes you'd group or filter by — geography, opt-in, signup date. What's out, and why:

- **`email`, `phone`** — PII with no analytical grouping value; analytics tables get copied into BI tools, exports, and screenshots, so the safest PII policy is "not present". (Keying by `customer_id`, not email, is also 7.3's stability argument.)
- **`lifetime_spend`** — it's a *derived aggregate of the fact table*, so storing it in the dimension is Pitfall 3 in its purest form: stale one order after every refresh, and ambiguous besides (gross? net? excluding cancelled?). Analysts compute it at query time — `SUM(item_revenue) ... GROUP BY customer_id` with the canonical filters — so it is always current and its definition is visible in the query.

One caveat to name in your design notes: `city`/`country` are *current* values, so revenue "by country" reflects where customers live now, not where they lived when they ordered. If that distinction matters, dimensions get versioned — the slowly-changing-dimension (SCD) pattern that `price_history` already demonstrates for prices.
