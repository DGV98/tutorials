#!/usr/bin/env python3
"""Deterministic data generator for the SQL course database (shop.db).

Generates a realistic e-commerce dataset for "Nordkart", a fictional
online outdoor-gear retailer, spanning 2023-01-01 .. 2026-07-14:

  - customers / addresses          (some customers never order)
  - categories (self-referencing)  (for recursive CTEs)
  - suppliers / products           (some products never sell)
  - price_history                  (slowly-changing prices)
  - orders / order_items           (growth trend + Nov/Dec seasonality)
  - payments                       (incl. failed + retried payments)
  - shipments                      (NULL delivered_at while in transit)
  - reviews                        (skewed ratings, some NULL text)
  - events                         (clickstream sessions, for windows)

Everything is seeded (random.seed) so re-running reproduces the exact
same database. No third-party dependencies.

Usage:
    python3 data/generate_data.py            # writes data/seed.sql and shop.db
"""

from __future__ import annotations

import os
import random
import sqlite3
from datetime import datetime, timedelta

random.seed(42)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SEED_SQL_PATH = os.path.join(HERE, "seed.sql")
DB_PATH = os.path.join(ROOT, "shop.db")

START = datetime(2023, 1, 1)
END = datetime(2026, 7, 14, 23, 59, 59)

# ---------------------------------------------------------------------------
# Name pools (no external deps)
# ---------------------------------------------------------------------------

FIRST_NAMES = [
    "Alma", "Anders", "Astrid", "Axel", "Birgitta", "Bjorn", "Carina",
    "Casper", "Clara", "Dag", "Ebba", "Einar", "Elin", "Elias", "Emma",
    "Erik", "Eva", "Felix", "Freja", "Frida", "Gunnar", "Gustav", "Hanna",
    "Hans", "Hedda", "Henrik", "Hugo", "Ida", "Ingrid", "Isak", "Johan",
    "Jonas", "Karin", "Karl", "Katja", "Kirsten", "Lars", "Lea", "Leif",
    "Linnea", "Lisa", "Liv", "Lukas", "Magnus", "Maja", "Marta", "Mats",
    "Mette", "Mikael", "Nils", "Noah", "Nora", "Oskar", "Otto", "Per",
    "Petra", "Ragnar", "Rasmus", "Rebecka", "Rune", "Saga", "Sara",
    "Sigrid", "Simon", "Sofia", "Sonja", "Stellan", "Sven", "Thea",
    "Tobias", "Tove", "Ulf", "Vera", "Viktor", "Wilma", "Yusuf", "Amara",
    "Chen", "Dmitri", "Fatima", "Giulia", "Hiro", "Ines", "Javier",
    "Kwame", "Leila", "Marco", "Nadia", "Omar", "Priya", "Rosa",
]

LAST_NAMES = [
    "Andersson", "Berg", "Bergstrom", "Blom", "Dahl", "Ek", "Eriksson",
    "Fisker", "Fors", "Gran", "Gustafsson", "Hagen", "Hansen", "Holm",
    "Ivarsson", "Jansson", "Johansson", "Karlsson", "Kron", "Lager",
    "Larsson", "Lind", "Lindqvist", "Lund", "Lundgren", "Magnusson",
    "Moller", "Nilsson", "Norberg", "Nyström", "Olsen", "Olsson",
    "Persson", "Pettersson", "Rask", "Sandberg", "Sjoberg", "Solberg",
    "Sten", "Strand", "Strom", "Sund", "Svensson", "Vik", "Wall",
    "Westergaard", "Ahmed", "Costa", "Duarte", "Fernandez", "Ivanov",
    "Kim", "Kowalski", "Nakamura", "Okafor", "Patel", "Ricci", "Santos",
    "Schmidt", "Tanaka", "Yilmaz",
]

# (country, [cities]) — weights applied below
GEO = [
    ("Sweden", ["Stockholm", "Gothenburg", "Malmo", "Uppsala", "Umea"]),
    ("Norway", ["Oslo", "Bergen", "Trondheim", "Stavanger"]),
    ("Denmark", ["Copenhagen", "Aarhus", "Odense", "Aalborg"]),
    ("Finland", ["Helsinki", "Tampere", "Turku", "Oulu"]),
    ("Germany", ["Berlin", "Munich", "Hamburg", "Cologne", "Frankfurt"]),
    ("Netherlands", ["Amsterdam", "Rotterdam", "Utrecht"]),
    ("United Kingdom", ["London", "Manchester", "Edinburgh", "Bristol"]),
    ("France", ["Paris", "Lyon", "Grenoble"]),
    ("Austria", ["Vienna", "Innsbruck", "Salzburg"]),
    ("Switzerland", ["Zurich", "Geneva", "Bern"]),
]
GEO_WEIGHTS = [22, 14, 12, 9, 14, 7, 8, 6, 4, 4]

STREETS = [
    "Storgatan", "Kungsgatan", "Fjordvej", "Havnegade", "Bergweg",
    "Lindenstrasse", "Main Street", "Rue de la Paix", "Kirkegata",
    "Mannerheimintie", "Drottninggatan", "Nyhavn", "Hauptstrasse",
    "Baker Street", "Aleksanterinkatu", "Karl Johans gate",
]

EMAIL_DOMAINS = [
    "gmail.com", "gmail.com", "gmail.com", "outlook.com", "outlook.com",
    "yahoo.com", "proton.me", "icloud.com", "hotmail.com", "fastmail.com",
]

CARRIERS = ["PostNord", "DHL", "UPS", "Bring", "DPD"]
PAYMENT_METHODS = ["card", "card", "card", "card", "paypal", "paypal", "klarna", "klarna", "bank_transfer"]

# ---------------------------------------------------------------------------
# Categories: 6 top-level, children below (self-referencing tree)
# ---------------------------------------------------------------------------

CATEGORY_TREE = {
    "Camping": ["Tents", "Sleeping Bags", "Camp Kitchen", "Backpacks"],
    "Climbing": ["Ropes & Slings", "Harnesses", "Carabiners & Hardware"],
    "Hiking": ["Hiking Boots", "Trekking Poles", "Navigation"],
    "Winter Sports": ["Skis", "Snowshoes", "Avalanche Safety"],
    "Water Sports": ["Kayaks", "Paddles", "Dry Bags"],
    "Apparel": ["Jackets", "Base Layers", "Gloves & Hats"],
}

# (adjective pool, noun pool, price range) per child category
PRODUCT_RECIPES = {
    "Tents": (["Alpine", "Trail", "Basecamp", "Storm", "Nordic"], ["Tent 2P", "Tent 3P", "Tunnel Tent", "Dome Tent", "Ultralight Tent"], (89, 750)),
    "Sleeping Bags": (["Polar", "Summit", "Fjell", "Aurora", "Glacier"], ["Sleeping Bag -5C", "Sleeping Bag -20C", "Down Bag", "Liner", "Quilt"], (35, 480)),
    "Camp Kitchen": (["Compact", "Titan", "Trek", "Fire", "Scout"], ["Stove", "Cook Set", "Kettle", "Spork Set", "Water Filter"], (9, 160)),
    "Backpacks": (["Ridge", "Vandra", "Nomad", "Crest", "Packrat"], ["Backpack 35L", "Backpack 50L", "Backpack 70L", "Daypack 20L", "Hydration Pack"], (39, 320)),
    "Ropes & Slings": (["Dyna", "Core", "Edge", "Anchor", "Flux"], ["Rope 60m", "Rope 70m", "Sling 120cm", "Cordelette", "Static Rope 40m"], (18, 290)),
    "Harnesses": (["Aero", "Grip", "Wall", "Crag", "Via"], ["Harness", "Kids Harness", "Big Wall Harness", "Chest Harness"], (35, 190)),
    "Carabiners & Hardware": (["Lock", "Swift", "Omni", "Micro", "Forge"], ["Carabiner", "Quickdraw Set", "Belay Device", "Ascender", "Pulley"], (7, 140)),
    "Hiking Boots": (["Terra", "Fjall", "Granite", "Moss", "Cairn"], ["Hiking Boots", "Trail Runners", "Approach Shoes", "Winter Boots"], (69, 280)),
    "Trekking Poles": (["Carbon", "Flex", "Stride", "Alu", "Peak"], ["Trekking Poles", "Folding Poles", "Ski Poles"], (25, 150)),
    "Navigation": (["Path", "True", "Orion", "Scout", "Vector"], ["Compass", "GPS Unit", "Altimeter Watch", "Map Case"], (12, 420)),
    "Skis": (["Powder", "Drift", "Tele", "Randonee", "Fjell"], ["Touring Skis", "Cross-Country Skis", "Ski Skins", "Ski Bindings"], (95, 780)),
    "Snowshoes": (["Yeti", "Trapper", "Flake", "Crust"], ["Snowshoes 25in", "Snowshoes 30in", "Kids Snowshoes"], (55, 240)),
    "Avalanche Safety": (["Pulse", "Rescue", "Probe", "Guard"], ["Avalanche Beacon", "Probe 240cm", "Snow Shovel", "Airbag Pack"], (35, 900)),
    "Kayaks": (["Fjord", "Wave", "Skerry", "Drift"], ["Touring Kayak", "Inflatable Kayak", "Sit-on-Top Kayak", "Spray Skirt"], (45, 1200)),
    "Paddles": (["Blade", "Swift", "Carbon", "Loom"], ["Kayak Paddle", "SUP Paddle", "Canoe Paddle"], (29, 340)),
    "Dry Bags": (["Seal", "Aqua", "Tide", "Splash"], ["Dry Bag 10L", "Dry Bag 20L", "Dry Bag 40L", "Phone Case"], (8, 75)),
    "Jackets": (["Storm", "Fjell", "Aurora", "Drizzle", "Vind"], ["Rain Jacket", "Down Jacket", "Softshell Jacket", "Wind Shell", "Insulated Parka"], (59, 520)),
    "Base Layers": (["Merino", "Thermo", "Wool", "Core"], ["Base Layer Top", "Base Layer Bottom", "Merino Tee", "Merino Socks 3pk"], (15, 120)),
    "Gloves & Hats": (["Frost", "Grip", "Polar", "Fleece"], ["Gloves", "Mittens", "Beanie", "Balaclava", "Sun Hat"], (9, 85)),
}

SUPPLIER_NAMES = [
    "Fjellutstyr AS", "Nordic Trail Supply", "Alpin Werke GmbH", "Baltic Gear Oy",
    "Highland Outfitters Ltd", "Skagen Outdoor ApS", "Bergsport Austria GmbH",
    "TrailCraft BV", "Polaris Equipment AB", "Glacier Goods AG", "Vandra Sport AB",
    "Kaiku Outdoor Oy", "Rein Gear AS", "Tundra Textiles Oy", "Cairn Supply Co",
    "Fjord Marine AS", "Summit Forge Ltd", "Wattenmeer Sports GmbH",
    "Lofoten Gear AS", "Aurora Apparel AB", "Basecamp Wholesale BV",
    "Kompass Praezision GmbH", "Nordkapp Trading AS", "Sila Outdoor Oy",
    "Crag & Crest Ltd", "Dovre Equipment AS", "Elbe Outdoor GmbH",
    "Falken Sport AG", "Gotland Gear AB", "Hardanger Supply AS",
    "Isbre Products AS", "Jura Alpine SA", "Kattegat Marine ApS",
    "Lapland Works Oy", "Malaren Sport AB", "Neva Outdoor OU",
    "Oslofjord Gear AS", "Pyreneen Sport SARL", "Quercus Outdoor SL",
    "Rhein Gear GmbH",
]

REVIEW_SNIPPETS_GOOD = [
    "Excellent quality, exceeded my expectations.",
    "Held up great on a week-long trip in Lapland.",
    "Light, sturdy, and packs down small. Would buy again.",
    "Perfect fit and fast delivery.",
    "Great value for the price point.",
    "Survived a storm on the Hardangervidda plateau. Trustworthy gear.",
    "My third purchase from this brand. Never disappoints.",
    "Solid construction, thoughtful details.",
]
REVIEW_SNIPPETS_MID = [
    "Does the job, but the zipper feels flimsy.",
    "Decent, though sizing runs small.",
    "OK for the price. Nothing special.",
    "Works fine in dry weather, less convinced in rain.",
    "Average quality. Expected a bit more at this price.",
]
REVIEW_SNIPPETS_BAD = [
    "Broke after two uses. Very disappointed.",
    "Arrived with a defect, had to return it.",
    "Cheap materials, would not recommend.",
    "Not waterproof at all despite the claims.",
    "Sizing chart is completely wrong.",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def rand_dt(lo: datetime, hi: datetime) -> datetime:
    delta = (hi - lo).total_seconds()
    return lo + timedelta(seconds=random.uniform(0, max(delta, 1)))


def month_weight(dt: datetime) -> float:
    """Growth trend + seasonality: holiday bump Nov/Dec, summer bump Jun/Jul."""
    months_since_start = (dt.year - START.year) * 12 + (dt.month - START.month)
    growth = 1.0 + 0.035 * months_since_start          # ~3.5% m/m growth
    season = {11: 1.5, 12: 1.8, 6: 1.25, 7: 1.3, 1: 0.8, 2: 0.85}.get(dt.month, 1.0)
    return growth * season


def sql_str(s: str | None) -> str:
    if s is None:
        return "NULL"
    return "'" + s.replace("'", "''") + "'"


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

def generate():
    rows: dict[str, list[tuple]] = {}

    # --- customers -------------------------------------------------------
    customers = []
    used_emails: set[str] = set()
    for cid in range(1, 801):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        base = f"{fn.lower()}.{ln.lower()}"
        email = f"{base}@{random.choice(EMAIL_DOMAINS)}"
        n = 1
        while email in used_emails:
            n += 1
            email = f"{base}{n}@{random.choice(EMAIL_DOMAINS)}"
        used_emails.add(email)
        country, cities = random.choices(GEO, weights=GEO_WEIGHTS, k=1)[0]
        city = random.choice(cities)
        phone = None if random.random() < 0.30 else "+%d %d" % (random.randint(30, 49), random.randint(10_000_000, 99_999_999))
        created = rand_dt(START - timedelta(days=365), END - timedelta(days=10))
        opt_in = 1 if random.random() < 0.42 else 0
        customers.append((cid, fn, ln, email, phone, country, city, opt_in, ts(created)))
    rows["customers"] = customers

    # --- addresses (1-3 per customer) -------------------------------------
    addresses = []
    aid = 0
    cust_addresses: dict[int, list[int]] = {}
    for c in customers:
        cid, country, city = c[0], c[5], c[6]
        n_addr = random.choices([1, 2, 3], weights=[70, 25, 5], k=1)[0]
        ids = []
        for i in range(n_addr):
            aid += 1
            a_country, a_city = (country, city) if i == 0 else random.choice([(country, city), random.choices(GEO, weights=GEO_WEIGHTS, k=1)[0][:1] + (random.choice(random.choices(GEO, weights=GEO_WEIGHTS, k=1)[0][1]),)])[0:2][0] if False else (country, city)
            # keep it simple: extra addresses stay in the same country, maybe new city
            if i > 0:
                a_city = random.choice(dict(GEO)[country])
            line1 = f"{random.choice(STREETS)} {random.randint(1, 220)}"
            postal = f"{random.randint(10000, 99999)}"
            addresses.append((aid, cid, line1, a_city, postal, a_country, 1 if i == 0 else 0))
            ids.append(aid)
        cust_addresses[cid] = ids
    rows["addresses"] = addresses

    # --- categories --------------------------------------------------------
    categories = []
    cat_id = 0
    child_cat_ids: dict[str, int] = {}
    for parent, children in CATEGORY_TREE.items():
        cat_id += 1
        parent_id = cat_id
        categories.append((parent_id, parent, None))
        for child in children:
            cat_id += 1
            categories.append((cat_id, child, parent_id))
            child_cat_ids[child] = cat_id
    rows["categories"] = categories

    # --- suppliers ---------------------------------------------------------
    suppliers = []
    for sid, name in enumerate(SUPPLIER_NAMES, start=1):
        country = random.choices(GEO, weights=GEO_WEIGHTS, k=1)[0][0]
        contact = name.lower().split()[0].replace("&", "and") + "@supplier.example"
        suppliers.append((sid, name, country, contact))
    rows["suppliers"] = suppliers

    # --- products ----------------------------------------------------------
    products = []
    pid = 0
    used_names: set[str] = set()
    while pid < 350:
        child = random.choice(list(PRODUCT_RECIPES.keys()))
        adjs, nouns, (lo, hi) = PRODUCT_RECIPES[child]
        name = f"{random.choice(adjs)} {random.choice(nouns)}"
        if name in used_names:
            continue
        used_names.add(name)
        pid += 1
        price = round(random.uniform(lo, hi), 2)
        cost = round(price * random.uniform(0.42, 0.68), 2)
        sku = f"NK-{child_cat_ids[child]:02d}-{pid:04d}"
        introduced = rand_dt(START - timedelta(days=200), END - timedelta(days=60))
        is_active = 0 if random.random() < 0.07 else 1
        products.append((pid, sku, name, child_cat_ids[child], random.randint(1, len(SUPPLIER_NAMES)), price, cost, is_active, ts(introduced)))
    rows["products"] = products

    product_intro = {p[0]: datetime.strptime(p[8], "%Y-%m-%d %H:%M:%S") for p in products}
    product_price = {p[0]: p[5] for p in products}

    # --- price_history -----------------------------------------------------
    price_history = []
    ph_id = 0
    # price at time t per product: list of (valid_from, price)
    price_timeline: dict[int, list[tuple[datetime, float]]] = {}
    for p in products:
        pid_, price, introduced = p[0], p[5], product_intro[p[0]]
        n_changes = random.choices([0, 1, 2, 3], weights=[35, 35, 20, 10], k=1)[0]
        change_dates = sorted(rand_dt(introduced + timedelta(days=45), END - timedelta(days=5)) for _ in range(n_changes))
        timeline = []
        # reconstruct backwards from current price so the LAST row equals products.unit_price
        prices = [price]
        for _ in range(n_changes):
            prices.append(round(prices[-1] / random.uniform(0.88, 1.18), 2))
        prices.reverse()  # oldest first, ends at current price
        starts = [introduced] + list(change_dates)
        for i, (start_dt, pr) in enumerate(zip(starts, prices)):
            end_dt = starts[i + 1] if i + 1 < len(starts) else None
            ph_id += 1
            price_history.append((ph_id, pid_, pr, ts(start_dt), ts(end_dt) if end_dt else None))
            timeline.append((start_dt, pr))
        price_timeline[pid_] = timeline
    rows["price_history"] = price_history

    def price_at(pid_: int, when: datetime) -> float:
        current = price_timeline[pid_][0][1]
        for start_dt, pr in price_timeline[pid_]:
            if start_dt <= when:
                current = pr
            else:
                break
        return current

    # --- orders + order_items + payments + shipments -----------------------
    # 8% of customers never order
    ordering_customers = [c for c in customers if random.random() >= 0.08]
    # popularity: 90% of products sellable; some never ordered
    sellable = [p for p in products if random.random() >= 0.10]
    product_pop = {p[0]: random.expovariate(1.0) + 0.05 for p in sellable}

    orders, order_items, payments, shipments = [], [], [], []
    oid = pay_id = ship_id = 0
    NOW = datetime(2026, 7, 15, 12, 0, 0)

    # heavy-tailed customer affinity: most order rarely, a few are power buyers
    affinity = {c[0]: random.expovariate(1.0) + 0.08 for c in ordering_customers}
    cust_by_id = {c[0]: c for c in ordering_customers}
    cust_ids = list(affinity.keys())
    cust_weights = list(affinity.values())

    TARGET_ORDERS = 6000
    while oid < TARGET_ORDERS:
        cid = random.choices(cust_ids, weights=cust_weights, k=1)[0]
        c = cust_by_id[cid]
        created = datetime.strptime(c[8], "%Y-%m-%d %H:%M:%S")
        first_possible = max(created, START)
        if first_possible >= END:
            continue
        if True:
            when = rand_dt(first_possible, END)
            # apply seasonality/growth by rejection sampling
            if random.random() > month_weight(when) / 4.5:
                continue
            oid += 1
            status_roll = random.random()
            age_days = (NOW - when).days
            if status_roll < 0.05:
                status = "cancelled"
            elif status_roll < 0.08:
                status = "returned" if age_days > 20 else "delivered"
            elif age_days < 3:
                status = "pending"
            elif age_days < 10:
                status = random.choice(["paid", "shipped"])
            elif age_days < 18:
                status = random.choice(["shipped", "delivered", "delivered"])
            else:
                status = "delivered"
            address_id = random.choice(cust_addresses[cid])
            shipping_cost = random.choice([0.0, 0.0, 4.9, 4.9, 9.9, 14.9])

            # items: 1-6 distinct products
            n_items = random.choices([1, 2, 3, 4, 5, 6], weights=[38, 28, 16, 10, 5, 3], k=1)[0]
            pool = [p for p in sellable if product_intro[p[0]] <= when]
            if not pool:
                oid -= 1
                continue
            weights = [product_pop[p[0]] for p in pool]
            chosen: dict[int, int] = {}
            for _ in range(n_items):
                prod = random.choices(pool, weights=weights, k=1)[0]
                chosen[prod[0]] = chosen.get(prod[0], 0) + random.choices([1, 1, 1, 2, 3], weights=[55, 20, 10, 10, 5], k=1)[0]
            total = 0.0
            for prod_id, qty in chosen.items():
                unit_price = price_at(prod_id, when)
                discount = random.choices([0, 0, 0, 0, 5, 10, 15, 20], weights=[55, 10, 5, 5, 10, 8, 5, 2], k=1)[0]
                order_items.append((oid, prod_id, qty, unit_price, discount))
                total += qty * unit_price * (1 - discount / 100.0)
            total = round(total + shipping_cost, 2)
            orders.append((oid, cid, address_id, status, shipping_cost, ts(when)))

            # payments
            if status != "cancelled" and status != "pending":
                # ~6% have a failed attempt first
                if random.random() < 0.06:
                    pay_id += 1
                    payments.append((pay_id, oid, total, random.choice(PAYMENT_METHODS), "failed", ts(when + timedelta(minutes=random.randint(1, 30)))))
                pay_id += 1
                payments.append((pay_id, oid, total, random.choice(PAYMENT_METHODS), "captured", ts(when + timedelta(minutes=random.randint(2, 240)))))
                if status == "returned":
                    pay_id += 1
                    payments.append((pay_id, oid, -total, "refund", "captured", ts(when + timedelta(days=random.randint(15, 40)))))
            elif status == "pending" and random.random() < 0.5:
                pay_id += 1
                payments.append((pay_id, oid, total, random.choice(PAYMENT_METHODS), "pending", ts(when + timedelta(minutes=5))))

            # shipments
            if status in ("shipped", "delivered", "returned"):
                ship_id += 1
                shipped_at = when + timedelta(days=random.randint(1, 4), hours=random.randint(0, 23))
                delivered_at = None
                if status in ("delivered", "returned"):
                    delivered_at = shipped_at + timedelta(days=random.randint(1, 9), hours=random.randint(0, 23))
                shipments.append((ship_id, oid, random.choice(CARRIERS), ts(shipped_at), ts(delivered_at) if delivered_at else None))

    rows["orders"] = orders
    rows["order_items"] = order_items
    rows["payments"] = payments
    rows["shipments"] = shipments

    # --- reviews (subset of delivered order items) --------------------------
    delivered_orders = {o[0]: o for o in orders if o[3] in ("delivered", "returned")}
    reviews = []
    seen_pairs: set[tuple[int, int]] = set()
    rid = 0
    for oi in order_items:
        o = delivered_orders.get(oi[0])
        if o is None or random.random() > 0.28:
            continue
        cid, prod_id = o[1], oi[1]
        if (prod_id, cid) in seen_pairs:
            continue
        seen_pairs.add((prod_id, cid))
        rid += 1
        rating = random.choices([1, 2, 3, 4, 5], weights=[4, 6, 13, 32, 45], k=1)[0]
        if random.random() < 0.35:
            text = None
        elif rating >= 4:
            text = random.choice(REVIEW_SNIPPETS_GOOD)
        elif rating == 3:
            text = random.choice(REVIEW_SNIPPETS_MID)
        else:
            text = random.choice(REVIEW_SNIPPETS_BAD)
        order_when = datetime.strptime(o[5], "%Y-%m-%d %H:%M:%S")
        created = order_when + timedelta(days=random.randint(7, 60))
        if created > NOW:
            created = NOW - timedelta(days=1)
        reviews.append((rid, prod_id, cid, rating, text, ts(created)))
    rows["reviews"] = reviews

    # --- events (clickstream sessions) --------------------------------------
    events = []
    eid = 0
    all_product_ids = [p[0] for p in products]
    for c in customers:
        cid = c[0]
        created = datetime.strptime(c[8], "%Y-%m-%d %H:%M:%S")
        first_possible = max(created, START)
        if first_possible >= END:
            continue
        n_sessions = random.choices([0, 1, 2, 4, 6, 10, 16], weights=[6, 12, 18, 22, 20, 14, 8], k=1)[0]
        for _ in range(n_sessions):
            session_start = rand_dt(first_possible, END)
            t = session_start
            n_ev = random.choices([1, 2, 3, 5, 8, 12], weights=[15, 22, 25, 20, 12, 6], k=1)[0]
            carted = False
            for i in range(n_ev):
                eid += 1
                roll = random.random()
                if roll < 0.68 or i == 0:
                    etype, prod = "page_view", random.choice(all_product_ids)
                elif roll < 0.88:
                    etype, prod = "add_to_cart", random.choice(all_product_ids)
                    carted = True
                elif carted and roll < 0.96:
                    etype, prod = "begin_checkout", None
                else:
                    etype, prod = "search", None
                events.append((eid, cid, etype, prod, ts(t)))
                t += timedelta(seconds=random.randint(10, 420))
    rows["events"] = events

    return rows


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE customers (
    customer_id      INTEGER PRIMARY KEY,
    first_name       TEXT NOT NULL,
    last_name        TEXT NOT NULL,
    email            TEXT NOT NULL UNIQUE,
    phone            TEXT,
    country          TEXT NOT NULL,
    city             TEXT NOT NULL,
    marketing_opt_in INTEGER NOT NULL DEFAULT 0 CHECK (marketing_opt_in IN (0, 1)),
    created_at       TEXT NOT NULL
);

CREATE TABLE addresses (
    address_id  INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    line1       TEXT NOT NULL,
    city        TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    country     TEXT NOT NULL,
    is_default  INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1))
);

CREATE TABLE categories (
    category_id        INTEGER PRIMARY KEY,
    name               TEXT NOT NULL UNIQUE,
    parent_category_id INTEGER REFERENCES categories(category_id)
);

CREATE TABLE suppliers (
    supplier_id   INTEGER PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE,
    country       TEXT NOT NULL,
    contact_email TEXT
);

CREATE TABLE products (
    product_id    INTEGER PRIMARY KEY,
    sku           TEXT NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    category_id   INTEGER NOT NULL REFERENCES categories(category_id),
    supplier_id   INTEGER NOT NULL REFERENCES suppliers(supplier_id),
    unit_price    REAL NOT NULL CHECK (unit_price >= 0),
    unit_cost     REAL NOT NULL CHECK (unit_cost >= 0),
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    introduced_at TEXT NOT NULL
);

CREATE TABLE price_history (
    price_id   INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    price      REAL NOT NULL CHECK (price >= 0),
    valid_from TEXT NOT NULL,
    valid_to   TEXT              -- NULL = current price
);

CREATE TABLE orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
    address_id    INTEGER NOT NULL REFERENCES addresses(address_id),
    status        TEXT NOT NULL CHECK (status IN
                      ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'returned')),
    shipping_cost REAL NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    ordered_at    TEXT NOT NULL
);

CREATE TABLE order_items (
    order_id     INTEGER NOT NULL REFERENCES orders(order_id),
    product_id   INTEGER NOT NULL REFERENCES products(product_id),
    quantity     INTEGER NOT NULL CHECK (quantity > 0),
    unit_price   REAL NOT NULL CHECK (unit_price >= 0),   -- price at time of order
    discount_pct INTEGER NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 100),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE payments (
    payment_id INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    amount     REAL NOT NULL,     -- negative = refund
    method     TEXT NOT NULL CHECK (method IN
                   ('card', 'paypal', 'klarna', 'bank_transfer', 'refund')),
    status     TEXT NOT NULL CHECK (status IN ('pending', 'captured', 'failed')),
    paid_at    TEXT NOT NULL
);

CREATE TABLE shipments (
    shipment_id  INTEGER PRIMARY KEY,
    order_id     INTEGER NOT NULL REFERENCES orders(order_id),
    carrier      TEXT NOT NULL,
    shipped_at   TEXT NOT NULL,
    delivered_at TEXT              -- NULL = still in transit
);

CREATE TABLE reviews (
    review_id   INTEGER PRIMARY KEY,
    product_id  INTEGER NOT NULL REFERENCES products(product_id),
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    created_at  TEXT NOT NULL,
    UNIQUE (product_id, customer_id)
);

CREATE TABLE events (
    event_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    event_type  TEXT NOT NULL CHECK (event_type IN
                    ('page_view', 'add_to_cart', 'begin_checkout', 'search')),
    product_id  INTEGER REFERENCES products(product_id),
    occurred_at TEXT NOT NULL
);
"""

COLUMNS = {
    "customers": "(customer_id, first_name, last_name, email, phone, country, city, marketing_opt_in, created_at)",
    "addresses": "(address_id, customer_id, line1, city, postal_code, country, is_default)",
    "categories": "(category_id, name, parent_category_id)",
    "suppliers": "(supplier_id, name, country, contact_email)",
    "products": "(product_id, sku, name, category_id, supplier_id, unit_price, unit_cost, is_active, introduced_at)",
    "price_history": "(price_id, product_id, price, valid_from, valid_to)",
    "orders": "(order_id, customer_id, address_id, status, shipping_cost, ordered_at)",
    "order_items": "(order_id, product_id, quantity, unit_price, discount_pct)",
    "payments": "(payment_id, order_id, amount, method, status, paid_at)",
    "shipments": "(shipment_id, order_id, carrier, shipped_at, delivered_at)",
    "reviews": "(review_id, product_id, customer_id, rating, review_text, created_at)",
    "events": "(event_id, customer_id, event_type, product_id, occurred_at)",
}

TABLE_ORDER = [
    "customers", "addresses", "categories", "suppliers", "products",
    "price_history", "orders", "order_items", "payments", "shipments",
    "reviews", "events",
]


def value_sql(v) -> str:
    if v is None:
        return "NULL"
    if isinstance(v, str):
        return sql_str(v)
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)


def main():
    rows = generate()

    lines = ["-- Nordkart e-commerce dataset (generated by data/generate_data.py — do not edit by hand)",
             "-- Rebuild with:  sqlite3 shop.db < data/seed.sql   (from an empty file)", ""]
    lines.append(SCHEMA)
    lines.append("BEGIN TRANSACTION;")
    for table in TABLE_ORDER:
        data = rows[table]
        lines.append(f"\n-- {table}: {len(data)} rows")
        for i in range(0, len(data), 200):
            chunk = data[i:i + 200]
            values = ",\n".join("  (" + ", ".join(value_sql(v) for v in r) + ")" for r in chunk)
            lines.append(f"INSERT INTO {table} {COLUMNS[table]} VALUES\n{values};")
    lines.append("COMMIT;")
    lines.append("ANALYZE;")

    with open(SEED_SQL_PATH, "w") as f:
        f.write("\n".join(lines) + "\n")

    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    with open(SEED_SQL_PATH) as f:
        conn.executescript(f.read())
    conn.commit()

    print(f"Wrote {SEED_SQL_PATH}")
    print(f"Built {DB_PATH}")
    for table in TABLE_ORDER:
        n = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"  {table:15s} {n:>7,} rows")
    conn.close()


if __name__ == "__main__":
    main()
