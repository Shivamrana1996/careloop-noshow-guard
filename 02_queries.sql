-- =========================================================
-- 02_queries.sql  —  Part 2: SQL  (CareLoop Clinics — No-Show Guard)
-- =========================================================

-- ---------- Task 2.1: Build and load the database ----------
DROP DATABASE IF EXISTS noshowguard;   -- only so the script can be re-run cleanly
CREATE DATABASE noshowguard;
USE noshowguard;

CREATE TABLE clinics (
  clinic_id VARCHAR(5) PRIMARY KEY, clinic_name VARCHAR(40) NOT NULL, city VARCHAR(20) NOT NULL,
  tier VARCHAR(10), latitude DECIMAL(8,4), longitude DECIMAL(8,4), temp_c DECIMAL(5,1));

CREATE TABLE appointments (
  appointment_id VARCHAR(8) PRIMARY KEY, patient_id VARCHAR(8) NOT NULL, clinic_id VARCHAR(5) NOT NULL,
  booked_on DATE, appt_date DATE, age INT, gender VARCHAR(1), distance_km DECIMAL(5,1), fee_inr INT,
  booking_channel VARCHAR(10), visit_type VARCHAR(12), reminder_sent VARCHAR(3), prior_no_shows INT,
  status VARCHAR(10), lead_days INT, no_show INT,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id));

-- Data loaded by running load_data.sql (8 clinics first, then 990 appointments)


-- Check the load
SELECT COUNT(*) AS clinics FROM clinics;                                     -- expect 8
SELECT COUNT(*) AS appointments, SUM(no_show) AS no_shows FROM appointments; -- expect 990 and 218

-- Duplicate-key test: A0001 already exists, so this insert must fail
INSERT INTO appointments VALUES ('A0001','P509','C05','2025-01-24','2025-01-25',60,'F',18.0,850,'Phone','Consultation','Yes',1,'No-Show',1,1);
-- Error recorded: Error Code: 1062. Duplicate entry 'A0001' for key 'appointments.PRIMARY'

-- ---------- Task 2.2: No-show rate by clinic ----------
-- (a) Only clinics with at least 95 appointments
SELECT c.clinic_name, c.city,
       COUNT(*) AS appointments,
       SUM(a.no_show) AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;

-- (b) Same query WITHOUT the HAVING line: all 8 clinics
SELECT c.clinic_name, c.city,
       COUNT(*) AS appointments,
       SUM(a.no_show) AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON a.clinic_id = c.clinic_id
GROUP BY c.clinic_name, c.city
ORDER BY no_show_pct DESC;

-- Finding: Gomti Nagar Care Point (Lucknow) has the HIGHEST rate, 33.3%, but only 90 appointments,
-- so HAVING >= 95 filtered it out. Sitabuldi Health Point (Nagpur) also drops out: 82 appointments, 15.9%.
-- Pandas cross-check (groupby) is at the end of 01_ingest_clean.ipynb: counts match exactly.

-- ---------- Task 2.3: Does booking far ahead matter? ----------
SELECT CASE
         WHEN lead_days <= 7  THEN '1-7'      -- 7 belongs to this band
         WHEN lead_days <= 14 THEN '8-14'     -- only reached if lead_days > 7
         WHEN lead_days <= 30 THEN '15-30'    -- only reached if lead_days > 14
         ELSE '31+'
       END AS lead_band,
       COUNT(*) AS appointments,
       SUM(no_show) AS no_shows,
       ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments
GROUP BY lead_band
ORDER BY MIN(lead_days);   -- sorts bands by their shortest lead time; sorting by the text would put '15-30' before '8-14'

-- Finding: booking far ahead does NOT reduce no-shows; it raises them.
-- Up to 14 days the rate is flat (16.2%, 17.4%); it jumps to 30.0% for 15-30 days and 60.5% for 31+ days.
-- Note: the 31+ band has only 43 appointments, so that rate is less reliable.

-- ---------- Task 2.4: Month-by-month trend ----------
WITH monthly AS (
    SELECT SUBSTR(appt_date, 1, 7) AS month,                     -- '2025-01-25' -> '2025-01'
           COUNT(*) AS appointments,
           ROUND(100.0 * SUM(no_show) / COUNT(*), 1) AS no_show_pct
    FROM appointments
    GROUP BY month
)
SELECT month,
       appointments,
       no_show_pct,
       ROUND(no_show_pct - LAG(no_show_pct) OVER (ORDER BY month), 1) AS change_pp   -- this month minus last month
FROM monthly
ORDER BY month;

-- Finding: no strong seasonal pattern. The rate stays between 20.4% and 24.8%.
-- January is highest (24.8%), Feb-Apr settle near 20.5%, May rises to 23.7%, June falls to 21.2%.
-- Monthly moves are small (at most 4.3 points) with about 140-200 appointments a month.


-- ---------- Task 2.5: Rank clinics inside each city ----------
-- Overall no-show rate, for reference (expect 22.02)
SELECT ROUND(100.0 * SUM(no_show) / COUNT(*), 2) AS overall_pct FROM appointments;

WITH clinic_rates AS (
    SELECT c.clinic_name AS clinic,
           c.city,
           ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
    FROM appointments a
    JOIN clinics c ON a.clinic_id = c.clinic_id
    GROUP BY c.clinic_name, c.city
)
SELECT clinic,
       city,
       no_show_pct,
       RANK() OVER (PARTITION BY city ORDER BY no_show_pct DESC) AS rank_in_city,   -- ranking restarts in each city
       CASE
         WHEN no_show_pct > (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'above'
         WHEN no_show_pct < (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'below'
         ELSE 'equal'
       END AS vs_overall
FROM clinic_rates
ORDER BY city, rank_in_city;

-- Finding: 4 clinics are above the overall 22.02% (Gomti Nagar 33.3, Hadapsar 27.3, Malviya Nagar 26.8, Kothrud 22.5).
-- Same city, very different results: in Jaipur, Malviya Nagar (26.8%) is almost double Vaishali Nagar (13.8%).
-- Only Pune and Jaipur have 2 clinics; in the other 4 cities, rank 1 just means it is the only clinic.


