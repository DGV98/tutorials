-- CityWheels capstone — quality_report.sql
-- Counts every issue class found in the raw exports and what the load did
-- about it. Run AFTER load.sql:  sqlite3 -box citywheels.db ".read quality_report.sql"

.headers on

WITH matched AS (        -- unified rows with their station lookups attached
    SELECT t.*,
           ss.name AS start_canonical,
           es.name AS end_canonical
    FROM stg_trips_all t
    LEFT JOIN stations ss ON LOWER(TRIM(t.start_station_name)) = LOWER(ss.name)
    LEFT JOIN stations es ON LOWER(TRIM(t.end_station_name))   = LOWER(es.name)
)
SELECT '01  raw rows, trips_2025.csv' AS metric,
       (SELECT COUNT(*) FROM stg_trips_2025) AS value
UNION ALL SELECT '02  raw rows, trips_2026.csv',
       (SELECT COUNT(*) FROM stg_trips_2026)
UNION ALL SELECT '03  exact-duplicate rows removed by dedup',
       (SELECT COUNT(*) FROM stg_trips_2025)
     + (SELECT COUNT(*) FROM stg_trips_2026)
     - (SELECT COUNT(*) FROM stg_trips_all)
UNION ALL SELECT '04  distinct trips after dedup',
       (SELECT COUNT(*) FROM stg_trips_all)
UNION ALL SELECT '05  quarantined: unknown station',
       (SELECT COUNT(*) FROM trips_quarantine
        WHERE reject_reason LIKE '%unknown station%')
UNION ALL SELECT '06  quarantined: ended before started',
       (SELECT COUNT(*) FROM trips_quarantine
        WHERE reject_reason LIKE '%ended before started%')
UNION ALL SELECT '07  quarantined total',
       (SELECT COUNT(*) FROM trips_quarantine)
UNION ALL SELECT '08  station-name fields repaired (trim/case-fold)',
       (SELECT SUM((start_station_name <> start_canonical COLLATE BINARY)
                 + (end_station_name   <> end_canonical   COLLATE BINARY))
        FROM matched
        WHERE start_canonical IS NOT NULL AND end_canonical IS NOT NULL)
UNION ALL SELECT '09  user_type values case-folded',
       (SELECT COUNT(*) FROM stg_trips_all
        WHERE user_type <> LOWER(TRIM(user_type)))
UNION ALL SELECT '10  blank user_birth_year -> NULL',
       (SELECT COUNT(*) FROM stg_trips_all WHERE user_birth_year = '')
UNION ALL SELECT '11  absurd user_birth_year (outside 1920-2012) -> NULL',
       (SELECT COUNT(*) FROM stg_trips_all
        WHERE user_birth_year <> ''
          AND CAST(user_birth_year AS INTEGER) NOT BETWEEN 1920 AND 2012)
UNION ALL SELECT '12  blank member price imputed to 0.00',
       (SELECT COUNT(*) FROM stg_trips_all
        WHERE price = '' AND LOWER(TRIM(user_type)) = 'member')
UNION ALL SELECT '13  final rows: stations',
       (SELECT COUNT(*) FROM stations)
UNION ALL SELECT '14  final rows: bikes',
       (SELECT COUNT(*) FROM bikes)
UNION ALL SELECT '15  final rows: maintenance',
       (SELECT COUNT(*) FROM maintenance)
UNION ALL SELECT '16  final rows: trips',
       (SELECT COUNT(*) FROM trips)
UNION ALL SELECT '17  reconciliation: dedup = quarantine + trips',
       (SELECT COUNT(*) FROM stg_trips_all)
     - (SELECT COUNT(*) FROM trips_quarantine)
     - (SELECT COUNT(*) FROM trips);
