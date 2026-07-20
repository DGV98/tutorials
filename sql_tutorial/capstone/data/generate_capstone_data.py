#!/usr/bin/env python3
"""Generate the raw CityWheels CSV exports for the capstone.

Deterministic (random.seed(7)), stdlib only. Writes five CSVs into
capstone/data/raw/:

    stations.csv      clean station master data
    trips_2025.csv    trips started in 2025, ISO timestamps
    trips_2026.csv    trips started in 2026, 'DD/MM/YYYY HH:MM' timestamps
                      (the vendor "upgraded" their export format)
    bikes.csv         clean bike master data
    maintenance.csv   clean maintenance log

The trip exports contain deliberate data-quality problems (exact duplicates,
negative durations, dirty station names, mixed user_type casing, bad birth
years, an unregistered pop-up station, blank member prices, mispriced trips).
Rerunning this script reproduces the identical files byte for byte.
"""

import csv
import math
import os
import random
from datetime import date, datetime, timedelta

random.seed(7)

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
os.makedirs(RAW, exist_ok=True)

FIRST_DAY = date(2025, 1, 1)
LAST_DAY = date(2026, 6, 30)

# ---------------------------------------------------------------- stations

DISTRICT_STATIONS = {
    "Harborfront": ["Harbor East", "Harbor West", "Ferry Landing", "Pier 12",
                    "Seawall Promenade", "Dockside Market", "Marina Green",
                    "Lighthouse Point"],
    "Old Town": ["Old Town Square", "Cathedral Gate", "Cobbler's Row",
                 "Merchant Hall", "Clocktower Plaza", "King's Cross Lane",
                 "Tannery Yard", "Guildhall Steps"],
    "Midtown": ["Central Station", "City Hall", "Grand & 3rd", "Grand & 9th",
                "Union Plaza", "Opera House", "Meridian Tower",
                "Fountain Court", "Exchange Street"],
    "University": ["University Gate", "Science Quad", "Library Mall",
                   "Student Commons", "Observatory Hill", "Athletics Center",
                   "Campus North"],
    "Riverside": ["Riverside Walk", "Willow Bend", "Old Mill Crossing",
                  "Kayak Launch", "Heron Park", "Floodgate Road",
                  "Ferry Meadow"],
    "Northgate": ["Northgate Mall", "Aurora & 22nd", "Aurora & 40th",
                  "Birchwood Terrace", "Summit Ridge", "Poplar Circle",
                  "Northgate Transit Hub"],
    "Westfield": ["Westfield Green", "Foundry District", "Steelworks Gate",
                  "Warehouse Row", "Gasometer Park", "Tramline Depot",
                  "Weaver Street"],
    "Cedar Park": ["Cedar Park Loop", "Rosemont & 5th", "Orchard Lane",
                   "Hillcrest Point", "Maple Grove", "Sunset Boulevard",
                   "Botanic Gardens"],
}

DISTRICT_CENTER = {
    "Harborfront": (44.9030, -92.2210),
    "Old Town":    (44.9180, -92.2050),
    "Midtown":     (44.9320, -92.1900),
    "University":  (44.9480, -92.1720),
    "Riverside":   (44.9150, -92.1650),
    "Northgate":   (44.9660, -92.1880),
    "Westfield":   (44.9280, -92.2350),
    "Cedar Park":  (44.9520, -92.2120),
}

stations = []           # dicts: station_id, name, district, lat, lon, capacity
station_weight = {}     # name -> popularity weight
sid = 1
for district, names in DISTRICT_STATIONS.items():
    clat, clon = DISTRICT_CENTER[district]
    for name in names:
        w = random.lognormvariate(0, 0.7)
        # central business / transit stations get a popularity boost
        if name in ("Central Station", "University Gate", "Harbor East",
                    "Old Town Square", "Northgate Transit Hub", "City Hall"):
            w *= 3.0
        station_weight[name] = w
        stations.append({
            "station_id": sid,
            "name": name,
            "district": district,
            "latitude": round(clat + random.uniform(-0.012, 0.012), 5),
            "longitude": round(clon + random.uniform(-0.015, 0.015), 5),
            "capacity": max(10, min(40, int(8 + w * 5 + random.uniform(0, 8)))),
        })
        sid += 1

station_names = [s["name"] for s in stations]
weights = [station_weight[n] for n in station_names]

# commuter pairs: residential-ish -> hub, ridden disproportionately often
COMMUTER_PAIRS = [
    ("University Gate", "Central Station"),
    ("Student Commons", "Library Mall"),
    ("Northgate Transit Hub", "City Hall"),
    ("Cedar Park Loop", "Central Station"),
    ("Harbor East", "Old Town Square"),
    ("Riverside Walk", "Exchange Street"),
    ("Birchwood Terrace", "Northgate Transit Hub"),
    ("Westfield Green", "Grand & 3rd"),
    ("Maple Grove", "University Gate"),
    ("Ferry Landing", "Central Station"),
]
partner = {a: b for a, b in COMMUTER_PAIRS}

# ------------------------------------------------------------------- bikes

BATCHES = [  # (batch date, count)
    (date(2023, 4, 10), 60), (date(2023, 9, 5), 40),
    (date(2024, 3, 18), 60), (date(2024, 8, 22), 40),
    (date(2025, 2, 14), 50), (date(2025, 6, 2), 40),
    (date(2025, 10, 20), 30), (date(2026, 2, 9), 30),
]
MODELS = [("Metro One", 0.5), ("Metro LS", 0.3), ("Volt-E", 0.2)]

bikes = []      # dicts: bike_id, model, acquired (date), weight
bid = 1001
for batch_day, count in BATCHES:
    for _ in range(count):
        r = random.random()
        model = "Metro One" if r < 0.5 else ("Metro LS" if r < 0.8 else "Volt-E")
        bikes.append({
            "bike_id": bid,
            "model": model,
            "acquired": batch_day + timedelta(days=random.randint(0, 6)),
            "weight": random.gammavariate(2.0, 1.0) + 0.05,
        })
        bid += 1

bikes.sort(key=lambda b: (b["acquired"], b["bike_id"]))

# a few well-used bikes go out of service for a long stretch (lost, vandalism,
# warehouse queue) -> long idle gaps for Part B
outage_candidates = sorted(
    (b for b in bikes if b["acquired"] < date(2024, 9, 30)),
    key=lambda b: -b["weight"],
)[:20]
outages = {}    # bike_id -> (start_date, end_date)
for b in random.sample(outage_candidates, 6):
    start = FIRST_DAY + timedelta(days=random.randint(60, 360))
    outages[b["bike_id"]] = (start, start + timedelta(days=random.randint(45, 75)))

# ------------------------------------------------------------------- trips

MONTH_FACTOR = {1: 0.55, 2: 0.60, 3: 0.80, 4: 1.00, 5: 1.25, 6: 1.40,
                7: 1.50, 8: 1.45, 9: 1.20, 10: 0.95, 11: 0.70, 12: 0.50}
HOUR_W_WEEKDAY = [0.2, 0.1, 0.08, 0.05, 0.05, 0.3, 1.2, 2.6, 3.4, 1.8, 1.2,
                  1.3, 1.6, 1.5, 1.4, 1.8, 2.6, 3.6, 2.8, 1.8, 1.3, 0.9,
                  0.6, 0.35]
HOUR_W_WEEKEND = [0.4, 0.25, 0.15, 0.08, 0.05, 0.1, 0.3, 0.7, 1.3, 2.0, 2.6,
                  3.0, 3.2, 3.1, 2.9, 2.6, 2.2, 1.9, 1.6, 1.3, 1.0, 0.8,
                  0.6, 0.5]
HOURS = list(range(24))


def price_for(user_type, dur_sec):
    """CityWheels pricing. casual: $1.00 unlock + $0.15/min.
    member: first 45 min included, then $0.10/min overage."""
    minutes = math.ceil(dur_sec / 60)
    if user_type == "casual":
        return round(1.00 + 0.15 * minutes, 2)
    return 0.0 if minutes <= 45 else round(0.10 * (minutes - 45), 2)


trips = []              # mutable dicts, chronological
trips_per_bike = {}     # bike_id -> count (drives maintenance volume)

day = FIRST_DAY
while day <= LAST_DAY:
    base = 38 if day.year == 2025 else 48
    dow = day.weekday()
    dow_factor = 1.05 if dow < 5 else (0.95 if dow == 5 else 0.80)
    mu = base * MONTH_FACTOR[day.month] * dow_factor
    if random.random() < 0.06:          # a rainy day
        mu *= 0.45
    n = max(5, int(random.gauss(mu, mu * 0.15)))

    hour_w = HOUR_W_WEEKDAY if dow < 5 else HOUR_W_WEEKEND
    available = [b for b in bikes if b["acquired"] <= day]
    avail_weights = [b["weight"] for b in available]
    member_p = 0.65 if dow < 5 else 0.45

    day_trips = []
    for _ in range(n):
        hour = random.choices(HOURS, weights=hour_w)[0]
        started = datetime(day.year, day.month, day.day, hour,
                           random.randint(0, 59), random.randint(0, 59))
        user_type = "member" if random.random() < member_p else "casual"
        if user_type == "member":
            dur = random.lognormvariate(math.log(11 * 60), 0.55)
        else:
            dur = random.lognormvariate(math.log(22 * 60), 0.65)
        dur = int(max(120, min(10800, dur)))
        ended = started + timedelta(seconds=dur)

        start_name = random.choices(station_names, weights=weights)[0]
        r = random.random()
        if r < 0.18 and start_name in partner:
            end_name = partner[start_name]
        elif r < 0.24:
            end_name = start_name          # round trip
        else:
            end_name = random.choices(station_names, weights=weights)[0]

        for _attempt in range(10):
            bike = random.choices(available, weights=avail_weights)[0]
            window = outages.get(bike["bike_id"])
            if window is None or not (window[0] <= day <= window[1]):
                break

        day_trips.append({
            "started": started, "ended": ended,
            "start_name": start_name, "end_name": end_name,
            "bike_id": bike["bike_id"], "user_type": user_type,
            "birth_year": str(int(random.triangular(1956, 2008, 1992))),
            "price": price_for(user_type, dur),
        })
        trips_per_bike[bike["bike_id"]] = trips_per_bike.get(bike["bike_id"], 0) + 1

    day_trips.sort(key=lambda t: t["started"])
    trips.extend(day_trips)
    day += timedelta(days=1)

N = len(trips)
counts = {"trips_generated": N}

# ---------------------------------------------------- deliberate messiness

all_idx = list(range(N))

# 1) a pop-up dock served a June 2025 festival but was never registered
popup_pool = [i for i in all_idx
              if date(2025, 6, 13) <= trips[i]["started"].date() <= date(2025, 6, 15)]
popup_idx = set(random.sample(popup_pool, min(14, len(popup_pool))))
for i in popup_idx:
    side = "start_name" if random.random() < 0.5 else "end_name"
    trips[i][side] = "Pop-up Dock 1"
counts["popup_station_trips"] = len(popup_idx)

# 2) ~0.5% of trips have ended_at before started_at (clock glitch)
neg_pool = [i for i in all_idx if i not in popup_idx]
neg_idx = set(random.sample(neg_pool, int(N * 0.005)))
for i in neg_idx:
    trips[i]["ended"] = trips[i]["started"] - timedelta(
        minutes=random.randint(3, 90))
counts["negative_duration_trips"] = len(neg_idx)

# 3) birth years: some blank, some absurd
by_pool = list(all_idx)
blank_by_idx = set(random.sample(by_pool, int(N * 0.03)))
for i in blank_by_idx:
    trips[i]["birth_year"] = ""
absurd_pool = [i for i in by_pool if i not in blank_by_idx]
absurd_by_idx = set(random.sample(absurd_pool, int(N * 0.006)))
for i in absurd_by_idx:
    trips[i]["birth_year"] = str(random.choice([1900, 2020]))
counts["blank_birth_year"] = len(blank_by_idx)
counts["absurd_birth_year"] = len(absurd_by_idx)

# 4) user_type arrives with inconsistent casing
n_ut_dirty = 0
for t in trips:
    r = random.random()
    if t["user_type"] == "member":
        if r < 0.12:
            t["user_type"] = "Member"
        elif r < 0.16:
            t["user_type"] = "MEMBER"
    else:
        if r < 0.15:
            t["user_type"] = "Casual"
    if t["user_type"] not in ("member", "casual"):
        n_ut_dirty += 1
counts["dirty_user_type"] = n_ut_dirty

# 5) station names with stray whitespace / wrong case
n_name_dirty = 0
for t in trips:
    for side in ("start_name", "end_name"):
        if t[side] == "Pop-up Dock 1":
            continue
        r = random.random()
        if r < 0.025:
            v = random.random()
            if v < 0.40:
                t[side] = t[side] + " "
            elif v < 0.70:
                t[side] = t[side].lower()
            elif v < 0.90:
                t[side] = t[side].upper()
            else:
                t[side] = " " + t[side]
            n_name_dirty += 1
counts["dirty_station_names"] = n_name_dirty

# 6) a handful of member trips exported with a blank price instead of 0.00
#    (members ride free under 45 min; the billing feed emits no row, and the
#    export writes an empty field)
blank_price_pool = [i for i in all_idx
                    if trips[i]["user_type"].lower() == "member"
                    and trips[i]["price"] == 0.0
                    and i not in neg_idx and i not in popup_idx]
blank_price_idx = set(random.sample(blank_price_pool, 60))
for i in blank_price_idx:
    trips[i]["price"] = None
counts["blank_member_price"] = len(blank_price_idx)

# 7) mispriced trips for the Part B price audit: casual rides charged $0.00
#    and a fat-finger batch charged 10x
audit_pool = [i for i in all_idx
              if trips[i]["user_type"].lower() == "casual"
              and i not in neg_idx and i not in popup_idx]
zero_price_idx = set(random.sample(audit_pool, 18))
for i in zero_price_idx:
    trips[i]["price"] = 0.0
tenx_pool = [i for i in audit_pool if i not in zero_price_idx]
tenx_price_idx = set(random.sample(tenx_pool, 12))
for i in tenx_price_idx:
    trips[i]["price"] = round(trips[i]["price"] * 10, 2)
counts["price_zeroed_casual"] = len(zero_price_idx)
counts["price_tenfold_casual"] = len(tenx_price_idx)

# ------------------------------------------------------------- trip files

for i, t in enumerate(trips):
    t["trip_id"] = 100001 + i


def iso(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def vendor2026(dt):
    return dt.strftime("%d/%m/%Y %H:%M")


HEADER = ["trip_id", "started_at", "ended_at", "start_station_name",
          "end_station_name", "bike_id", "user_type", "user_birth_year",
          "price"]


def to_row(t, fmt):
    return [t["trip_id"], fmt(t["started"]), fmt(t["ended"]),
            t["start_name"], t["end_name"], t["bike_id"], t["user_type"],
            t["birth_year"],
            "" if t["price"] is None else f"{t['price']:.2f}"]


def write_trip_file(fname, year, fmt):
    rows = [to_row(t, fmt) for t in trips if t["started"].year == year]
    # 8) ~1% exact duplicate rows (export retries), inserted right after the
    #    original so the file still looks sorted
    dup_positions = sorted(random.sample(range(len(rows)), int(len(rows) * 0.01)),
                           reverse=True)
    for p in dup_positions:
        rows.insert(p + 1, list(rows[p]))
    with open(os.path.join(RAW, fname), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        w.writerows(rows)
    return len(rows), len(dup_positions)


n25, d25 = write_trip_file("trips_2025.csv", 2025, iso)
n26, d26 = write_trip_file("trips_2026.csv", 2026, vendor2026)
counts["rows_trips_2025"] = n25
counts["dup_rows_2025"] = d25
counts["rows_trips_2026"] = n26
counts["dup_rows_2026"] = d26

# ------------------------------------------------------ clean master files

with open(os.path.join(RAW, "stations.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["station_id", "name", "district", "latitude", "longitude",
                "capacity"])
    for s in stations:
        w.writerow([s["station_id"], s["name"], s["district"], s["latitude"],
                    s["longitude"], s["capacity"]])

with open(os.path.join(RAW, "bikes.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["bike_id", "model", "acquired_date"])
    for b in sorted(bikes, key=lambda b: b["bike_id"]):
        w.writerow([b["bike_id"], b["model"], b["acquired"].isoformat()])

MAINT_TYPES = [  # (type, cost_lo, cost_hi)
    ("flat_tire", 12, 25), ("brake_adjustment", 15, 30),
    ("chain_replacement", 28, 55), ("tune_up", 40, 75),
    ("wheel_true", 20, 40),
]
maintenance = []
for b in sorted(bikes, key=lambda b: b["bike_id"]):
    used = trips_per_bike.get(b["bike_id"], 0)
    n_maint = used // 45 + (1 if random.random() < (used % 45) / 45 else 0)
    n_maint += random.choice([0, 0, 0, 1])
    if b["model"] == "Volt-E" and used > 0 and random.random() < 0.6:
        n_maint += 1                     # battery service visit
    lo = max(b["acquired"], FIRST_DAY)
    span = (LAST_DAY - lo).days
    for k in range(n_maint):
        if b["model"] == "Volt-E" and k == n_maint - 1 and random.random() < 0.5:
            mtype, clo, chi = "battery_service", 60, 120
        else:
            mtype, clo, chi = random.choice(MAINT_TYPES)
        maintenance.append({
            "bike_id": b["bike_id"],
            "date": lo + timedelta(days=random.randint(0, max(span, 1))),
            "type": mtype,
            "cost": round(random.uniform(clo, chi), 2),
        })
maintenance.sort(key=lambda m: (m["date"], m["bike_id"]))
with open(os.path.join(RAW, "maintenance.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["maintenance_id", "bike_id", "maintenance_date",
                "maintenance_type", "cost"])
    for i, m in enumerate(maintenance):
        w.writerow([5001 + i, m["bike_id"], m["date"].isoformat(), m["type"],
                    f"{m['cost']:.2f}"])

counts["stations"] = len(stations)
counts["bikes"] = len(bikes)
counts["maintenance_rows"] = len(maintenance)

print("CityWheels raw export written to", RAW)
for k, v in counts.items():
    print(f"  {k:24s} {v}")
