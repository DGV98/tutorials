-- CityWheels capstone — schema.sql
-- Staging tables (raw text, mirrors the CSVs), final normalized tables with
-- constraints, and a quarantine table for irreparable rows.
-- Run:  sqlite3 citywheels.db ".read schema.sql"

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------- staging
-- Everything TEXT: staging's job is to receive the files exactly as they
-- are. Typing, cleaning, and rejecting happen on the way OUT of staging.

DROP TABLE IF EXISTS stg_stations;
CREATE TABLE stg_stations (
    station_id TEXT, name TEXT, district TEXT,
    latitude TEXT, longitude TEXT, capacity TEXT
);

DROP TABLE IF EXISTS stg_bikes;
CREATE TABLE stg_bikes (
    bike_id TEXT, model TEXT, acquired_date TEXT
);

DROP TABLE IF EXISTS stg_maintenance;
CREATE TABLE stg_maintenance (
    maintenance_id TEXT, bike_id TEXT, maintenance_date TEXT,
    maintenance_type TEXT, cost TEXT
);

DROP TABLE IF EXISTS stg_trips_2025;
CREATE TABLE stg_trips_2025 (
    trip_id TEXT, started_at TEXT, ended_at TEXT,
    start_station_name TEXT, end_station_name TEXT,
    bike_id TEXT, user_type TEXT, user_birth_year TEXT, price TEXT
);

DROP TABLE IF EXISTS stg_trips_2026;
CREATE TABLE stg_trips_2026 (
    trip_id TEXT, started_at TEXT, ended_at TEXT,
    start_station_name TEXT, end_station_name TEXT,
    bike_id TEXT, user_type TEXT, user_birth_year TEXT, price TEXT
);

-- stg_trips_all: both exports unified — timestamps normalized to ISO,
-- exact-duplicate rows collapsed. Kept as a real table (not temp) so the
-- quality report can compare raw vs unified vs final. Populated by load.sql.
DROP TABLE IF EXISTS stg_trips_all;
CREATE TABLE stg_trips_all (
    trip_id TEXT, started_at TEXT, ended_at TEXT,
    start_station_name TEXT, end_station_name TEXT,
    bike_id TEXT, user_type TEXT, user_birth_year TEXT, price TEXT,
    source_file TEXT NOT NULL
);

-- ------------------------------------------------------------ final tables

DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS maintenance;
DROP TABLE IF EXISTS bikes;
DROP TABLE IF EXISTS stations;
DROP TABLE IF EXISTS trips_quarantine;

CREATE TABLE stations (
    station_id INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE COLLATE NOCASE,
    district   TEXT NOT NULL,
    latitude   REAL NOT NULL CHECK (latitude  BETWEEN -90 AND 90),
    longitude  REAL NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    capacity   INTEGER NOT NULL CHECK (capacity > 0)
);

CREATE TABLE bikes (
    bike_id       INTEGER PRIMARY KEY,
    model         TEXT NOT NULL,
    acquired_date TEXT NOT NULL CHECK (acquired_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')
);

CREATE TABLE maintenance (
    maintenance_id   INTEGER PRIMARY KEY,
    bike_id          INTEGER NOT NULL REFERENCES bikes (bike_id),
    maintenance_date TEXT NOT NULL,
    maintenance_type TEXT NOT NULL CHECK (maintenance_type IN
        ('flat_tire', 'brake_adjustment', 'chain_replacement',
         'tune_up', 'wheel_true', 'battery_service')),
    cost             REAL NOT NULL CHECK (cost >= 0)
);

-- trips references stations by id, not by name: the raw name spellings are
-- resolved once at load time, and the analytical tables never repeat the
-- district/coordinates (3NF — those depend on the station, not the trip).
CREATE TABLE trips (
    trip_id          INTEGER PRIMARY KEY,
    started_at       TEXT NOT NULL,           -- ISO-8601 'YYYY-MM-DD HH:MM:SS'
    ended_at         TEXT NOT NULL,
    start_station_id INTEGER NOT NULL REFERENCES stations (station_id),
    end_station_id   INTEGER NOT NULL REFERENCES stations (station_id),
    bike_id          INTEGER NOT NULL REFERENCES bikes (bike_id),
    user_type        TEXT NOT NULL CHECK (user_type IN ('member', 'casual')),
    user_birth_year  INTEGER CHECK (user_birth_year BETWEEN 1920 AND 2012),
    price            REAL NOT NULL CHECK (price >= 0),
    CHECK (ended_at >= started_at)
);

-- rows we cannot repair honestly are quarantined, never silently dropped
CREATE TABLE trips_quarantine (
    trip_id            TEXT,
    started_at         TEXT,
    ended_at           TEXT,
    start_station_name TEXT,
    end_station_name   TEXT,
    bike_id            TEXT,
    user_type          TEXT,
    user_birth_year    TEXT,
    price              TEXT,
    source_file        TEXT NOT NULL,
    reject_reason      TEXT NOT NULL
);

-- ---------------------------------------------------------------- indexes

CREATE INDEX idx_trips_started_at    ON trips (started_at);
CREATE INDEX idx_trips_bike_started  ON trips (bike_id, started_at);
CREATE INDEX idx_trips_start_station ON trips (start_station_id);
CREATE INDEX idx_trips_end_station   ON trips (end_station_id);
CREATE INDEX idx_maintenance_bike    ON maintenance (bike_id);
