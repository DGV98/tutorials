-- CityWheels capstone — load.sql
-- Imports the raw CSVs into staging, then cleans/normalizes into the final
-- tables, quarantining irreparable rows. Assumes schema.sql already ran.
-- Run from capstone/solutions/:  sqlite3 citywheels.db ".read load.sql"

.bail on
PRAGMA foreign_keys = ON;

-- ------------------------------------------------------- 1. import raw CSVs

.mode csv
.import --skip 1 ../data/raw/stations.csv    stg_stations
.import --skip 1 ../data/raw/bikes.csv       stg_bikes
.import --skip 1 ../data/raw/maintenance.csv stg_maintenance
.import --skip 1 ../data/raw/trips_2025.csv  stg_trips_2025
.import --skip 1 ../data/raw/trips_2026.csv  stg_trips_2026
.mode list

-- --------------------------------------------- 2. master data (clean files)

INSERT INTO stations (station_id, name, district, latitude, longitude, capacity)
SELECT CAST(station_id AS INTEGER),
       TRIM(name),
       TRIM(district),
       CAST(latitude  AS REAL),
       CAST(longitude AS REAL),
       CAST(capacity  AS INTEGER)
FROM stg_stations;

INSERT INTO bikes (bike_id, model, acquired_date)
SELECT CAST(bike_id AS INTEGER), TRIM(model), acquired_date
FROM stg_bikes;

INSERT INTO maintenance (maintenance_id, bike_id, maintenance_date,
                         maintenance_type, cost)
SELECT CAST(maintenance_id AS INTEGER),
       CAST(bike_id        AS INTEGER),
       maintenance_date,
       TRIM(maintenance_type),
       CAST(cost AS REAL)
FROM stg_maintenance;

-- ------------------- 3. unify the two trip exports into one staging table
-- The 2026 vendor format is 'DD/MM/YYYY HH:MM'; rearrange it to ISO-8601
-- with :00 seconds so both years compare, sort, and date-function alike.
-- SELECT DISTINCT collapses the exact-duplicate export rows (every column
-- identical, including trip_id) — this is the dedup step.

INSERT INTO stg_trips_all
SELECT DISTINCT trip_id, started_at, ended_at,
       start_station_name, end_station_name,
       bike_id, user_type, user_birth_year, price,
       'trips_2025.csv'
FROM stg_trips_2025;

INSERT INTO stg_trips_all
SELECT DISTINCT trip_id,
          substr(started_at, 7, 4) || '-' || substr(started_at, 4, 2) || '-'
       || substr(started_at, 1, 2) || ' ' || substr(started_at, 12, 5) || ':00',
          substr(ended_at, 7, 4)   || '-' || substr(ended_at, 4, 2)   || '-'
       || substr(ended_at, 1, 2)   || ' ' || substr(ended_at, 12, 5)   || ':00',
       start_station_name, end_station_name,
       bike_id, user_type, user_birth_year, price,
       'trips_2026.csv'
FROM stg_trips_2026;

-- --------------------------------------------- 4. quarantine irreparable rows
-- Unknown station (no coordinates/capacity to invent) and time-travel trips
-- (no defensible way to guess the real end time). Rows are kept verbatim
-- with a reason, never silently deleted.

INSERT INTO trips_quarantine
SELECT t.*,
       TRIM(
           CASE WHEN ss.station_id IS NULL OR es.station_id IS NULL
                THEN 'unknown station; ' ELSE '' END
        || CASE WHEN t.ended_at < t.started_at
                THEN 'ended before started; ' ELSE '' END
        || CASE WHEN t.price = '' AND LOWER(TRIM(t.user_type)) <> 'member'
                THEN 'missing price on paid trip; ' ELSE '' END,
       '; ')                                        AS reject_reason
FROM stg_trips_all t
LEFT JOIN stations ss ON LOWER(TRIM(t.start_station_name)) = LOWER(ss.name)
LEFT JOIN stations es ON LOWER(TRIM(t.end_station_name))   = LOWER(es.name)
WHERE ss.station_id IS NULL
   OR es.station_id IS NULL
   OR t.ended_at < t.started_at
   OR (t.price = '' AND LOWER(TRIM(t.user_type)) <> 'member');

-- ------------------------------------------------- 5. load the good rows
-- Repairs applied here (all reversible/documentable):
--   * station names: TRIM + case-insensitive match against stations.name
--   * user_type:     LOWER(TRIM(...)) -> 'member' / 'casual'
--   * birth year:    blank -> NULL; outside 1920–2012 (1900, 2020) -> NULL
--   * price:         blank on member trips -> 0.00 (members ride free up to
--                    45 min; the billing feed emits no row for free rides)

INSERT INTO trips (trip_id, started_at, ended_at, start_station_id,
                   end_station_id, bike_id, user_type, user_birth_year, price)
SELECT CAST(t.trip_id AS INTEGER),
       t.started_at,
       t.ended_at,
       ss.station_id,
       es.station_id,
       CAST(t.bike_id AS INTEGER),
       LOWER(TRIM(t.user_type)),
       CASE WHEN CAST(t.user_birth_year AS INTEGER) BETWEEN 1920 AND 2012
            THEN CAST(t.user_birth_year AS INTEGER)
       END,
       CASE WHEN t.price = '' THEN 0.00
            ELSE CAST(t.price AS REAL)
       END
FROM stg_trips_all t
JOIN stations ss ON LOWER(TRIM(t.start_station_name)) = LOWER(ss.name)
JOIN stations es ON LOWER(TRIM(t.end_station_name))   = LOWER(es.name)
WHERE t.ended_at >= t.started_at
  AND NOT (t.price = '' AND LOWER(TRIM(t.user_type)) <> 'member');

-- sanity echo
SELECT 'trips loaded: '      || COUNT(*) FROM trips;
SELECT 'trips quarantined: ' || COUNT(*) FROM trips_quarantine;
