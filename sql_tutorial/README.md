# Zero to Hero SQL

A hands-on SQL course for becoming the person on the team who *actually knows
SQL* — from your first `SELECT` to designing schemas, writing complex
analytical queries, tuning them, and structuring SQL like an engineer. It ends
with a capstone project and exam that certify you've earned it.

Everything runs locally against **SQLite** (already on your machine — the
course uses zero external services), with **PostgreSQL notes** throughout so
your knowledge transfers directly to the database you'll most likely use
professionally.

## The dataset

The whole course works one realistic database: **`shop.db`** — the operational
data of *Nordkart*, a fictional online outdoor-gear retailer. 12 tables, ~57k
rows, 3.5 years of orders, payments, shipments, reviews, and clickstream
events, with growth trends, seasonality, and the same NULLs and edge cases
real production data has.

Read **[DATASET.md](DATASET.md)** — it's your schema reference for the entire
course. The **[capstone](capstone/README.md)** uses a separate, deliberately
messy dataset you'll have to tame yourself.

## Setup (2 minutes)

```bash
# 1. Check sqlite3 is installed (3.39+ needed; you likely have newer)
sqlite3 --version

# 2. From this directory, build the database (only if shop.db is missing)
sqlite3 shop.db < data/seed.sql

# 3. Open it and make the output readable
sqlite3 shop.db
sqlite> .mode box
sqlite> .headers on
sqlite> SELECT COUNT(*) FROM orders;
```

If you ever wreck the database while experimenting: `rm shop.db` and rebuild
it with step 2. It's fully reproducible.

## Syllabus

| # | Module | You'll be able to… |
|---|--------|--------------------|
| 1 | [First Queries](modules/01-first-queries.md) | navigate a database and read data with SELECT, ORDER BY, LIMIT |
| 2 | [Filtering & NULL](modules/02-filtering-and-null.md) | filter precisely, reason about NULL three-valued logic, bucket with CASE |
| 3 | [Aggregation](modules/03-aggregation.md) | answer "how much / how many" questions with GROUP BY and HAVING |
| 4 | [Joins](modules/04-joins.md) | combine tables correctly and dodge the fan-out bugs that plague real teams |
| 5 | [Subqueries & CTEs](modules/05-subqueries-and-ctes.md) | compose multi-step queries, walk trees, generate date series |
| 6 | [Window Functions](modules/06-window-functions.md) | rank, compare to previous rows, running totals — the analyst superpower |
| 7 | [Data Modeling](modules/07-data-modeling.md) | design normalized schemas, know when to denormalize, build a star schema |
| 8 | [DDL, Constraints & Views](modules/08-ddl-constraints-views.md) | create tables that defend their own integrity |
| 9 | [DML & Transactions](modules/09-dml-and-transactions.md) | change data safely: upserts, transactions, idempotent loads |
| 10 | [Indexes & Performance](modules/10-indexes-and-performance.md) | read query plans and make slow queries fast |
| 11 | [Advanced Analytics](modules/11-advanced-analytics.md) | sessionization, cohorts, funnels, RFM, point-in-time joins |
| 12 | [SQL Style & Structure](modules/12-sql-style-and-structure.md) | write SQL others can read, test it, review it |
| 🎓 | [Capstone](capstone/README.md) | prove it: model a messy raw dataset and pass the exam |

Solutions for every module's exercises live in [`solutions/`](solutions/) —
one file per module. **Don't open them until you've attempted the exercises.**

## How to work through a module

1. **Type every query yourself.** Don't copy-paste. Muscle memory is half the
   skill.
2. **Predict before you run.** Before executing an example, guess what it
   returns. Being wrong is where learning happens.
3. **Do all exercises before opening the solutions file.** Warm-ups should
   take a minute; Challenges may take twenty. That's intended.
4. **Detour freely.** The dataset rewards curiosity — if you wonder "which
   carrier is slowest?", go find out.
5. Expect **1.5–3 hours per module**. Modules 4, 6, 7, and 11 are the heavy
   hitters; give them their own sittings.

## Repository layout

```
├── README.md              ← you are here
├── DATASET.md             ← schema reference (keep it open in a tab)
├── shop.db                ← the Nordkart database (rebuildable)
├── data/
│   ├── seed.sql           ← rebuilds shop.db exactly
│   └── generate_data.py   ← generated seed.sql (deterministic)
├── modules/               ← the 12 modules, in order
├── solutions/             ← exercise solutions (no peeking)
├── tests/                 ← SQL assertion test suite (built in Module 12)
└── capstone/              ← final project + exam (solutions quarantined inside)
```

## When you're done

You'll have: a portfolio-grade capstone (schema design, cleaning pipeline,
analytics suite), a personal SQL style guide and review checklist, and a
working knowledge of the difference between SQL that runs and SQL that's
*right*. The capstone rubric tells you whether you've hit mastery (≥85%).
