USE TFE_gold
GO

DROP VIEW IF EXISTS view_dim_airport;
DROP VIEW IF EXISTS view_dim_runway;
DROP VIEW IF EXISTS view_dim_aircraft;
DROP VIEW IF EXISTS view_dim_airlines;
DROP VIEW IF EXISTS category_weather_temperature;
DROP VIEW IF EXISTS category_weather_precipitation;
DROP VIEW IF EXISTS category_weather_cloud_cover_low;
DROP VIEW IF EXISTS category_weather_cloud_cover_mid;
DROP VIEW IF EXISTS category_weather_wind_speed;
DROP VIEW IF EXISTS category_weather_wind_gusts;
DROP VIEW IF EXISTS view_dim_category_weather_temp_precip;
DROP VIEW IF EXISTS view_dim_category_weather_wind_cloud;
DROP VIEW IF EXISTS view_fact_demographics;
DROP VIEW IF EXISTS view_fact_delay_weather;

GO


-- dim_airport
CREATE VIEW view_dim_airport
AS (
SELECT asize.Locid AS locid,
       asize.[Airport Name] AS airport_name,
       CASE
       -- replacing Kenner by New Orleans to ensure consistency
        WHEN asize.City = 'Kenner' THEN 'New Orleans'
        ELSE asize.City
       END as city,
       delay_a.OriginStateName as state,
       asize.Hub AS hub,
       asize.[CY 24 Enplanements] AS emplanement_2024
FROM TFE_silver.dbo.airport_size AS asize
    LEFT JOIN (SELECT DISTINCT Origin, OriginStateName 
                FROM TFE_silver.dbo.delay_airports) AS delay_a on delay_a.Origin = asize.Locid
    );

GO

INSERT INTO dim_airport
SELECT * 
FROM view_dim_airport;

GO

-- dim_runway

CREATE VIEW view_dim_runway 
AS (
SELECT ra.RWY_ID AS runway_name,
       ra.RWY_LEN_M AS runway_length,
       ra.RWY_WIDTH * 0.3048 AS runway_width,
CASE
  --Replacing the surface_type_code by the meaning
  WHEN ra.SURFACE_TYPE_CODE = 'CONC' THEN 'Concrete'
  WHEN ra.SURFACE_TYPE_CODE = 'ASPH' THEN 'Asphalt'
  WHEN ra.SURFACE_TYPE_CODE = 'ASPH-CONC' THEN 'Asphalt-Concrete'
  WHEN ra.SURFACE_TYPE_CODE = 'TURF' THEN 'Turf'
  ELSE ra.SURFACE_TYPE_CODE
END AS surface_type,
ra.COND AS condition,
ra.RWY_LGT_CODE AS runway_length_code,
asize.Locid as locid
FROM TFE_silver.dbo.runways_airport AS ra
    LEFT JOIN TFE_silver.dbo.airport_size AS asize on asize.Locid = ra.ARPT_ID
);

GO


INSERT INTO dim_runway
SELECT *
FROM view_dim_runway;

GO


-- dim_aircraft

CREATE VIEW view_dim_aircraft 
AS (
SELECT tn.REGISTRATION_NUMBER AS aircraft_registration_number,
       tn.[YEAR MFR] AS year_mfr,
       am.MFR as mfr,
       am.MODEL as model,
       am.[NO-SEATS]  as number_seats
FROM TFE_silver.dbo.tail_number AS tn
    LEFT JOIN TFE_silver.dbo.aircraft_model AS am on am.CODE = tn.[MFR MDL CODE]

UNION ALL
-- Adding registration numbers that are in the delay table but not in the tail_number table
SELECT DISTINCT da.Tail_Number AS aircraft_registration_number,
       NULL AS year_mfr,
       NULL AS mfr,
       NULL AS model,
       NULL AS number_seats
FROM TFE_silver.dbo.delay_airports AS da
WHERE da.Tail_Number NOT IN (
    SELECT tn.REGISTRATION_NUMBER
    FROM TFE_silver.dbo.tail_number AS tn
    WHERE tn.REGISTRATION_NUMBER IS NOT NULL)

);

GO



INSERT INTO dim_aircraft
SELECT *
FROM view_dim_aircraft;

GO

-- dim_airlines

CREATE VIEW view_dim_airlines
AS (
SELECT IATA_CODE_Reporting_Airline AS IATA_code,
       Airline_Name AS airline_name
FROM TFE_silver.dbo.airline
);

GO


INSERT INTO dim_airlines
SELECT *
FROM view_dim_airlines

GO

-- dim_date

-- ref: https://www.linkedin.com/pulse/creating-calendar-table-ms-sql-server-japankumar-pathak/

DECLARE @StartDate DATETIME
DECLARE @EndDate DATETIME
SET @StartDate = CONVERT(DATE,'2018-12-31')
SET @EndDate = CONVERT(DATE,'2026-01-01')


WHILE @StartDate <= @EndDate
      BEGIN
             INSERT INTO dim_date
             (
				   datekey, -- yyyymmdd
				   full_date,
				   [year],
				   [month],
				   [day],
                   day_of_week
             )
             SELECT
                   YEAR(@StartDate)*10000 + MONTH(@StartDate)*100 + DAY(@StartDate),
				   @StartDate,
				   YEAR(@StartDate),
				   MONTH(@StartDate),
				   Day(@StartDate),
                   DATENAME(WEEKDAY, @StartDate)


             SET @StartDate = DATEADD(dd, 1, @StartDate)


      END

GO

-- dim_time

DECLARE @i INT = 1
DECLARE @StartTime TIME


WHILE @i <= 1439
BEGIN
    SET @StartTime = CAST(
        DATEADD(MINUTE, @i, CAST('00:00' AS DATETIME))
        AS TIME
    )

    INSERT INTO dim_time (timekey, full_time, [hour], [minute])
    SELECT
        DATEPART(HOUR, @StartTime) * 100 + DATEPART(MINUTE, @StartTime),
        @StartTime,
        DATEPART(HOUR, @StartTime),
        DATEPART(MINUTE, @StartTime)

    SET @i = @i + 1
END

GO

-- Special line for midnight (24:00 in the delay table)
INSERT INTO dim_time (timekey, full_time, [hour], [minute])
VALUES (2400, '00:00', 0, 0)

GO


  -- dim_category_weather
  -- Separating the different weather measurements in different intervals

CREATE VIEW category_weather_temperature AS (
SELECT 
  temperature_2m,
  CASE 
    WHEN temperature_2m < -40    THEN '-50--41°C'
    WHEN temperature_2m < -30    THEN '-40--31°C'
    WHEN temperature_2m < -20    THEN '-30--21°C'
    WHEN temperature_2m < -10    THEN '-20--11°C'
    WHEN temperature_2m < 0      THEN '-10--1°C'
    WHEN temperature_2m < 10     THEN '0-9°C'
    WHEN temperature_2m < 20     THEN '10-19°C'
    WHEN temperature_2m < 30     THEN '20-29°C'
    WHEN temperature_2m < 40     THEN '30-39°C'
    ELSE '40-49°C'
  END AS description
FROM TFE_silver.dbo.weather
);

GO


CREATE VIEW category_weather_precipitation AS (
SELECT 
  precipitation, rain, snowfall,
  CASE 
    WHEN precipitation <= 0      THEN '0 mm (No Precipitation)'
    WHEN precipitation < 0.2     THEN '0-0.2 mm'
    WHEN precipitation < 0.4     THEN '0.2-0.4 mm'
    WHEN precipitation < 0.8     THEN '0.4-0.8 mm'
    WHEN precipitation < 1.6     THEN '0.8-1.6 mm'
    WHEN precipitation < 3.2     THEN '1.6-3.2 mm'
    WHEN precipitation < 6.4     THEN '3.2-6.4 mm'
    WHEN precipitation < 12.8    THEN '6.4-12.8 mm'
    WHEN precipitation < 25.6    THEN '12.8-25.6 mm'
    WHEN precipitation < 51.2    THEN '25.6-51.2 mm'
    ELSE '51.2mm+'
  END AS precip_category,
  CASE 
    WHEN precipitation = 0 THEN 'No Precipitation'
    WHEN rain > 0 AND snowfall = 0 THEN 'Rain'
    WHEN rain = 0 AND snowfall > 0 THEN 'Snow'
    WHEN rain > 0 AND snowfall > 0 THEN 'Mixed'
END AS precipitation_type
FROM TFE_silver.dbo.weather
)

GO


CREATE VIEW category_weather_cloud_cover_low AS(
SELECT 
  cloud_cover_low,
  CASE 
    WHEN cloud_cover_low = 0      THEN '0%'
    WHEN cloud_cover_low < 10     THEN '0-9%'
    WHEN cloud_cover_low < 20     THEN '10-19%'
    WHEN cloud_cover_low < 30     THEN '20-29%'
    WHEN cloud_cover_low < 40     THEN '30-39%'
    WHEN cloud_cover_low < 50     THEN '40-49%'
    WHEN cloud_cover_low < 60     THEN '50-59%'
    WHEN cloud_cover_low < 70     THEN '60-69%'
    WHEN cloud_cover_low < 80     THEN '70-79%'
    WHEN cloud_cover_low < 90     THEN '80-89%'
    ELSE '90-100%'
  END AS description
FROM TFE_silver.dbo.weather
);

GO


CREATE VIEW category_weather_cloud_cover_mid AS(
SELECT 
  cloud_cover_mid,
  CASE 
    WHEN cloud_cover_mid = 0      THEN '0%'
    WHEN cloud_cover_mid < 10     THEN '0-9%'
    WHEN cloud_cover_mid < 20     THEN '10-19%'
    WHEN cloud_cover_mid < 30     THEN '20-29%'
    WHEN cloud_cover_mid < 40     THEN '30-39%'
    WHEN cloud_cover_mid < 50     THEN '40-49%'
    WHEN cloud_cover_mid < 60     THEN '50-59%'
    WHEN cloud_cover_mid < 70     THEN '60-69%'
    WHEN cloud_cover_mid < 80     THEN '70-79%'
    WHEN cloud_cover_mid < 90     THEN '80-89%'
    ELSE '90-100%'
  END AS description
FROM TFE_silver.dbo.weather
);

GO

CREATE VIEW category_weather_wind_speed AS (
SELECT 
  wind_speed_10m,
  CASE 
    WHEN wind_speed_10m < 10      THEN '0-9 km/h'
    WHEN wind_speed_10m < 20      THEN '10-19 km/h'
    WHEN wind_speed_10m < 30      THEN '20-29 km/h'
    WHEN wind_speed_10m < 40      THEN '30-39 km/h'
    WHEN wind_speed_10m < 50      THEN '40-49 km/h'
    WHEN wind_speed_10m < 60      THEN '50-59 km/h'
    WHEN wind_speed_10m < 70      THEN '60-69 km/h'
    WHEN wind_speed_10m < 80      THEN '70-79 km/h'
    WHEN wind_speed_10m < 90      THEN '80-89 km/h'
    WHEN wind_speed_10m < 100     THEN '90-99 km/h'
    ELSE '100-110 km/h'
  END AS wind_speed_category
FROM TFE_silver.dbo.weather
);

GO

CREATE VIEW category_weather_wind_gusts AS (
SELECT 
  wind_gusts_10m,
  CASE 
    WHEN wind_gusts_10m < 10      THEN '0-9 km/h'
    WHEN wind_gusts_10m < 20      THEN '10-19 km/h'
    WHEN wind_gusts_10m < 30      THEN '20-29 km/h'
    WHEN wind_gusts_10m < 40      THEN '30-39 km/h'
    WHEN wind_gusts_10m < 50      THEN '40-49 km/h'
    WHEN wind_gusts_10m < 60      THEN '50-59 km/h'
    WHEN wind_gusts_10m < 70      THEN '60-69 km/h'
    WHEN wind_gusts_10m < 80      THEN '70-79 km/h'
    WHEN wind_gusts_10m < 90      THEN '80-89 km/h'
    WHEN wind_gusts_10m < 100     THEN '90-99 km/h'
    WHEN wind_gusts_10m < 110     THEN '100-109 km/h'
    WHEN wind_gusts_10m < 120     THEN '110-119 km/h'
    WHEN wind_gusts_10m < 130     THEN '120-129 km/h'
    WHEN wind_gusts_10m < 140     THEN '130-139 km/h'
    WHEN wind_gusts_10m < 150     THEN '140-149 km/h'
    WHEN wind_gusts_10m < 160     THEN '150-159 km/h'
    WHEN wind_gusts_10m < 170     THEN '160-169 km/h'
    WHEN wind_gusts_10m < 180     THEN '170-179 km/h'
    WHEN wind_gusts_10m < 190     THEN '180-189 km/h'
    WHEN wind_gusts_10m < 200     THEN '190-199 km/h'
    ELSE '200+ km/h'
  END AS wind_gusts_category
FROM TFE_silver.dbo.weather
);

GO

-- Obtaining combinations between different categories of temperature, precipitation and precipitation type
CREATE VIEW view_dim_category_weather_temp_precip AS (
SELECT t.temp_category, p.precip_category, p.precipitation_type,
  CONCAT(
    t.temp_category, ' & ',
    p.precip_category, ' & ',
    p.precipitation_type
  ) AS description
FROM (SELECT DISTINCT precip_category, precipitation_type FROM category_weather_precipitation) p
CROSS JOIN (SELECT DISTINCT description AS temp_category FROM category_weather_temperature) t
);

GO

INSERT INTO dim_category_weather_temp_precip
SELECT * FROM view_dim_category_weather_temp_precip;

GO

-- Obtaining combinations between different categories of wind speed, wind gusts, low cloud cover and mid cloud cover
CREATE VIEW view_dim_category_weather_wind_cloud AS (
SELECT ws.wind_speed_category, wg.wind_gusts_category, cl.cloud_low_category,cm.cloud_mid_category,
  CONCAT(
    ws.wind_speed_category, ' & ',
    wg.wind_gusts_category, ' & ',
    cl.cloud_low_category, ' & ',
    cm.cloud_mid_category
  ) AS description
FROM (SELECT DISTINCT wind_speed_category FROM category_weather_wind_speed) ws
CROSS JOIN (SELECT DISTINCT wind_gusts_category FROM category_weather_wind_gusts) wg
CROSS JOIN (SELECT DISTINCT description AS cloud_low_category FROM category_weather_cloud_cover_low) cl
CROSS JOIN (SELECT DISTINCT description AS cloud_mid_category FROM category_weather_cloud_cover_mid) cm
);

GO

INSERT INTO dim_category_weather_wind_cloud
SELECT * FROM view_dim_category_weather_wind_cloud;

GO

-- Fact Demographics

CREATE VIEW view_fact_demographics AS (
SELECT city AS demographics_id, 
       population AS population,
       median_household_income AS median_household_income_per_year,
       pop_25plus as pop_25plus,
       bachelors_count AS got_bachelors_diploma_count,
       [metropolitan statistical area/micropolitan statistical area] AS statistical_area,
       area_type,
  
       airport_id AS locid
FROM TFE_silver.dbo.demographics
);

GO


INSERT INTO fact_demographics
SELECT * 
FROM view_fact_demographics;

GO

-- Fact Delay avec categorie

CREATE VIEW view_fact_delay_weather AS 
WITH delay_cat AS (
    SELECT delay_a.*,
           m_instant.weather_code as weather_code,
           m_cumul.precipitation as precipitation,
           m_cumul.rain as rain,
           m_instant.temperature_2m as temperature,
           m_instant.snow_depth as snow_depth_m,
           m_cumul.snowfall as snow_fall_cm,
           m_instant.cloud_cover_low as cloud_cover_low,
           m_instant.cloud_cover_mid as cloud_cover_mid,
           m_instant.wind_speed_10m as wind_speed,
           m_cumul.wind_gusts_10m as wind_gusts,
           m_instant.wind_direction_10m as wind_direction,

           CASE 
               WHEN m_cumul.precipitation <= 0      THEN '0 mm (No Precipitation)'
               WHEN m_cumul.precipitation < 0.2     THEN '0-0.2 mm'
               WHEN m_cumul.precipitation < 0.4     THEN '0.2-0.4 mm'
               WHEN m_cumul.precipitation < 0.8     THEN '0.4-0.8 mm'
               WHEN m_cumul.precipitation < 1.6     THEN '0.8-1.6 mm'
               WHEN m_cumul.precipitation < 3.2     THEN '1.6-3.2 mm'
               WHEN m_cumul.precipitation < 6.4     THEN '3.2-6.4 mm'
               WHEN m_cumul.precipitation < 12.8    THEN '6.4-12.8 mm'
               WHEN m_cumul.precipitation < 25.6    THEN '12.8-25.6 mm'
               WHEN m_cumul.precipitation < 51.2    THEN '25.6-51.2 mm'
               ELSE '51.2mm+'
           END AS precip_category,

           CASE 
               WHEN m_instant.temperature_2m < -40    THEN '-50--41°C'
               WHEN m_instant.temperature_2m < -30    THEN '-40--31°C'
               WHEN m_instant.temperature_2m < -20    THEN '-30--21°C'
               WHEN m_instant.temperature_2m < -10    THEN '-20--11°C'
               WHEN m_instant.temperature_2m < 0      THEN '-10--1°C'
               WHEN m_instant.temperature_2m < 10     THEN '0-9°C'
               WHEN m_instant.temperature_2m < 20     THEN '10-19°C'
               WHEN m_instant.temperature_2m < 30     THEN '20-29°C'
               WHEN m_instant.temperature_2m < 40     THEN '30-39°C'
               ELSE '40-49°C'
           END AS temp_category,

           CASE 
              WHEN m_cumul.precipitation = 0 THEN 'No Precipitation'
              WHEN m_cumul.rain > 0 AND m_cumul.snowfall = 0 THEN 'Rain'
              WHEN m_cumul.rain = 0 AND m_cumul.snowfall > 0 THEN 'Snow'
              WHEN m_cumul.rain > 0 AND m_cumul.snowfall > 0 THEN 'Mixed'
           END AS precipitation_type,

           CASE 
               WHEN m_instant.wind_speed_10m < 10      THEN '0-9 km/h'
               WHEN m_instant.wind_speed_10m < 20      THEN '10-19 km/h'
               WHEN m_instant.wind_speed_10m < 30      THEN '20-29 km/h'
               WHEN m_instant.wind_speed_10m < 40      THEN '30-39 km/h'
               WHEN m_instant.wind_speed_10m < 50      THEN '40-49 km/h'
               WHEN m_instant.wind_speed_10m < 60      THEN '50-59 km/h'
               WHEN m_instant.wind_speed_10m < 70      THEN '60-69 km/h'
               WHEN m_instant.wind_speed_10m < 80      THEN '70-79 km/h'
               WHEN m_instant.wind_speed_10m < 90      THEN '80-89 km/h'
               WHEN m_instant.wind_speed_10m < 100     THEN '90-99 km/h'
               ELSE '100-110 km/h'
           END AS wind_speed_category,

           CASE 
               WHEN m_cumul.wind_gusts_10m < 10      THEN '0-9 km/h'
               WHEN m_cumul.wind_gusts_10m < 20      THEN '10-19 km/h'
               WHEN m_cumul.wind_gusts_10m < 30      THEN '20-29 km/h'
               WHEN m_cumul.wind_gusts_10m < 40      THEN '30-39 km/h'
               WHEN m_cumul.wind_gusts_10m < 50      THEN '40-49 km/h'
               WHEN m_cumul.wind_gusts_10m < 60      THEN '50-59 km/h'
               WHEN m_cumul.wind_gusts_10m < 70      THEN '60-69 km/h'
               WHEN m_cumul.wind_gusts_10m < 80      THEN '70-79 km/h'
               WHEN m_cumul.wind_gusts_10m < 90      THEN '80-89 km/h'
               WHEN m_cumul.wind_gusts_10m < 100     THEN '90-99 km/h'
               WHEN m_cumul.wind_gusts_10m < 110     THEN '100-109 km/h'
               WHEN m_cumul.wind_gusts_10m < 120     THEN '110-119 km/h'
               WHEN m_cumul.wind_gusts_10m < 130     THEN '120-129 km/h'
               WHEN m_cumul.wind_gusts_10m < 140     THEN '130-139 km/h'
               WHEN m_cumul.wind_gusts_10m < 150     THEN '140-149 km/h'
               WHEN m_cumul.wind_gusts_10m < 160     THEN '150-159 km/h'
               WHEN m_cumul.wind_gusts_10m < 170     THEN '160-169 km/h'
               WHEN m_cumul.wind_gusts_10m < 180     THEN '170-179 km/h'
               WHEN m_cumul.wind_gusts_10m < 190     THEN '180-189 km/h'
               WHEN m_cumul.wind_gusts_10m < 200     THEN '190-199 km/h'
               ELSE '200+ km/h'
           END AS wind_gusts_category,

           CASE 
               WHEN m_instant.cloud_cover_low = 0      THEN '0%'
               WHEN m_instant.cloud_cover_low < 10     THEN '0-9%'
               WHEN m_instant.cloud_cover_low < 20     THEN '10-19%'
               WHEN m_instant.cloud_cover_low < 30     THEN '20-29%'
               WHEN m_instant.cloud_cover_low < 40     THEN '30-39%'
               WHEN m_instant.cloud_cover_low < 50     THEN '40-49%'
               WHEN m_instant.cloud_cover_low < 60     THEN '50-59%'
               WHEN m_instant.cloud_cover_low < 70     THEN '60-69%'
               WHEN m_instant.cloud_cover_low < 80     THEN '70-79%'
               WHEN m_instant.cloud_cover_low < 90     THEN '80-89%'
               ELSE '90-100%'
           END AS cloud_low_category,

           CASE 
               WHEN m_instant.cloud_cover_mid = 0      THEN '0%'
               WHEN m_instant.cloud_cover_mid < 10     THEN '0-9%'
               WHEN m_instant.cloud_cover_mid < 20     THEN '10-19%'
               WHEN m_instant.cloud_cover_mid < 30     THEN '20-29%'
               WHEN m_instant.cloud_cover_mid < 40     THEN '30-39%'
               WHEN m_instant.cloud_cover_mid < 50     THEN '40-49%'
               WHEN m_instant.cloud_cover_mid < 60     THEN '50-59%'
               WHEN m_instant.cloud_cover_mid < 70     THEN '60-69%'
               WHEN m_instant.cloud_cover_mid < 80     THEN '70-79%'
               WHEN m_instant.cloud_cover_mid < 90     THEN '80-89%'
               ELSE '90-100%'
           END AS cloud_mid_category

    FROM TFE_silver.dbo.delay_airports as delay_a
    LEFT JOIN TFE_silver.dbo.weather as m_instant 
        ON CAST(m_instant.date AS DATE) = CAST(delay_a.FlightDate AS DATE) 
        AND delay_a.Origin = m_instant.locid 
        AND delay_a.tranche_horaire_instant = m_instant.tranche_horaire_instant
    LEFT JOIN TFE_silver.dbo.weather as m_cumul 
        ON CAST(m_cumul.date AS DATE) = CAST(delay_a.FlightDate AS DATE) 
        AND delay_a.Origin = m_cumul.locid 
        AND delay_a.tranche_horaire_cum = m_cumul.tranche_horaire_cum
)

SELECT dc.Origin as departure_locid,
       dc.Tail_Number as aircraft_registration_number,
       dc.IATA_CODE_Reporting_Airline as IATA_code,
       d.datekey as datekey,
       dc.TaxiOut as taxi_out,
       dc.WheelsOff as wheels_off,
       dc.CRSDepTime as crs_departure_time,
       dc.DepTime as departure_time,
       dc.WheelsOn as wheels_on,
       dc.TaxiIn as taxi_in,
       dc.CRSArrTime as crs_arrival_time,
       dc.ArrTime as arrival_time,
       dc.DepDelay as departure_delay,
       dc.ArrDelay as arrival_delay,
       dc.DepDelayPositive as departure_delay_positive,
       dc.ArrDelayPositive as arrival_delay_positive,
       dc.DepEarly as departure_early,
       dc.ArrEarly as arrival_early,
       dc.Cancelled as cancelled,
       dc.CancellationCode as cancellation_code,
       dc.Diverted as diverted,
       dc.CRSElapsedTime as crs_elapsed_time,
       dc.ActualElapsedTime as actual_elapsed_time,
       dc.DistanceKm as distance_km,
       dc.CarrierDelay as carrier_delay,
       dc.WeatherDelay as weather_delay,
       dc.NASDelay as NAS_delay,
       dc.SecurityDelay as security_delay,
       dc.LateAircraftDelay as late_aircraft_delay,
       dc.weather_code,
       dc.precipitation,
       dc.rain,
       dc.temperature,
       dc.snow_depth_m,
       dc.snow_fall_cm,
       dc.cloud_cover_low,
       dc.cloud_cover_mid,
       dc.wind_speed,
       dc.wind_gusts,
       dc.wind_direction,
       ctp.category_weather_temp_precip_id,
       cwc.category_weather_wind_cloud_id

FROM delay_cat dc
LEFT JOIN dim_date as d ON d.full_date = dc.FlightDate
LEFT JOIN dim_category_weather_temp_precip as ctp 
    ON dc.precip_category = ctp.precipitation_category 
    AND dc.temp_category = ctp.temperature_category 
    AND dc.precipitation_type = ctp.precipitation_type
LEFT JOIN dim_category_weather_wind_cloud as cwc
    ON dc.wind_speed_category = cwc.wind_speed_category
    AND dc.wind_gusts_category = cwc.wind_gusts_category 
    AND dc.cloud_low_category = cwc.cloud_low_category 
    AND dc.cloud_mid_category = cwc.cloud_mid_category;

GO

INSERT INTO fact_delay_weather
SELECT * 
FROM view_fact_delay_weather

-- SELECT * FROM fact_delay_weather
-- SELECT * FROM fact_demographics
-- SELECT * FROM dim_runway
-- SELECT * FROM dim_airport
-- SELECT * FROM dim_aircraft
-- SELECT * FROM dim_airlines
-- SELECT * FROM dim_date
-- SELECT * FROM dim_time
-- SELECT * FROM dim_category_weather_wind_cloud
-- SELECT * FROM dim_category_weather_temp_precip