--CREATE DATABASE TFE_silver
USE TFE_silver

GO 

DROP TABLE IF EXISTS TFE_silver.dbo.delay_airports;
DROP TABLE IF EXISTS TFE_silver.dbo.weather;     
DROP TABLE IF EXISTS TFE_silver.dbo.runways_airport;
DROP TABLE IF EXISTS TFE_silver.dbo.tail_number;
DROP TABLE IF EXISTS TFE_silver.dbo.demographics;
DROP TABLE IF EXISTS TFE_silver.dbo.airport_size;
DROP TABLE IF EXISTS TFE_silver.dbo.aircraft_model;
DROP TABLE IF EXISTS TFE_silver.dbo.airline;





GO






--Aircraft_model
SELECT CODE, 
	CASE
		WHEN MFR LIKE '%AIRBUS%' THEN 'AIRBUS'
		WHEN MFR LIKE '%BELL %' THEN 'BELL TEXTRON CANADA'
		WHEN MFR LIKE '%DIAMOND%' THEN 'DIAMOND AIRCRAFT IND'
		WHEN MFR LIKE '%EMBRAER%'THEN 'EMBRAER'
		WHEN MFR LIKE '%YABORA%' THEN 'EMBRAER'
		WHEN MFR LIKE '%MCDONNELL%' THEN 'MCDONNELL DOUGLASS'
		WHEN MFR LIKE '%MOONEY%' THEN 'MOONEY'
		ELSE MFR
	END as MFR, 
	MODEL, [NO-SEATS]
INTO TFE_silver.dbo.aircraft_model
FROM TFE_staging.dbo.aircraft_model;


--Airline
SELECT *
INTO TFE_silver.dbo.airline
FROM TFE_staging.dbo.airline;

GO

--Airport_size
SELECT Locid, [Airport Name], City, Hub, [CY 24 Enplanements], ST 
INTO TFE_silver.dbo.airport_size
FROM TFE_staging.dbo.airport_size;

GO


--Delay
SELECT DayOfWeek, FlightDate, IATA_CODE_Reporting_Airline, Tail_Number, Origin, CRSDepTime, DepTime, DepDelay, TaxiOut, WheelsOff, WheelsOn, TaxiIn, CRSArrTime, ArrTime, ArrDelay, 
Cancelled, CancellationCode, Diverted, CRSElapsedTime, ActualElapsedTime, DistanceKm, WeatherDelay, CarrierDelay,SecurityDelay,LateAircraftDelay, NASDelay, DepDelayPositive, ArrDelayPositive, 
DepEarly, ArrEarly, OriginStateName,
CASE
	-- Creating the two time slots: one for the temperature and one for the precipitation
	-- The CRSDepTime is in the HHmm format 
	WHEN CRSDepTime%100 > 0 THEN CAST((CRSDepTime/100) %24 AS VARCHAR) + 'h01 - ' + CAST((CRSDepTime/100 + 1) %24 AS VARCHAR) + 'h00'
	ELSE CAST((CRSDepTime/100 + 23) % 24 AS VARCHAR) + 'h01 - ' + CAST((CRSDepTime/100) % 24 AS VARCHAR) + 'h00'
END as tranche_horaire_cum,
CASE
	WHEN CRSDepTime%100 BETWEEN 31 AND 59 THEN CAST((CRSDepTime/100) %24 AS VARCHAR) + 'h31 - ' + CAST((CRSDepTime/100 + 1) %24 AS VARCHAR) + 'h30'
	WHEN CRSDepTime%100 BETWEEN 0 AND 30 THEN CAST((CRSDepTime/100 +23) %24 AS VARCHAR) + 'h31 - ' + CAST((CRSDepTime/100) %24 AS VARCHAR) + 'h30'
END as tranche_horaire_instant
INTO TFE_silver.dbo.delay_airports
FROM TFE_staging.dbo.delay_airports;

GO

--Demographics
SELECT population, median_household_income, pop_25plus, bachelors_count, [metropolitan statistical area/micropolitan statistical area], city, state, area_type, airport_id
INTO TFE_silver.dbo.demographics
FROM TFE_staging.dbo.demographics;

GO

--Weather
SELECT date, locid, temperature_2m, precipitation, rain, snowfall, snow_depth, weather_code, cloud_cover_low, cloud_cover_mid, wind_speed_10m, wind_gusts_10m, wind_direction_10m,
   -- Creating the two time slots: one for the temperature and one for the precipitation
CAST((DATEPART(HOUR, date) + 23) %24 AS VARCHAR) + 'h31 - ' + CAST(DATEPART(HOUR, date) AS VARCHAR) + 'h30' as tranche_horaire_instant,
CAST((DATEPART(HOUR, date) + 23) %24 AS VARCHAR) + 'h01 - ' + CAST(DATEPART(HOUR, date) AS VARCHAR) + 'h00' as tranche_horaire_cum
INTO TFE_silver.dbo.weather
FROM TFE_staging.dbo.weather;

GO


--Runways_airport
SELECT ARPT_ID, RWY_ID, RWY_LEN_M, RWY_WIDTH, SURFACE_TYPE_CODE, COND, RWY_LGT_CODE
INTO TFE_silver.dbo.runways_airport
FROM TFE_staging.dbo.runways_airport;

GO

--Tail_number
SELECT REGISTRATION_NUMBER, [MFR MDL CODE], [YEAR MFR]
INTO TFE_silver.dbo.tail_number
FROM TFE_staging.dbo.tail_number;



-- Assigning the primary keys



GO

ALTER TABLE tail_number ALTER COLUMN REGISTRATION_NUMBER VARCHAR(100) NOT NULL;

GO

ALTER TABLE tail_number ADD CONSTRAINT PK_tail_number PRIMARY KEY (REGISTRATION_NUMBER);

GO

ALTER TABLE aircraft_model ALTER COLUMN CODE VARCHAR(100) NOT NULL;

GO

ALTER TABLE aircraft_model ADD CONSTRAINT PK_aircraft_model PRIMARY KEY (CODE);

GO

ALTER TABLE demographics ALTER COLUMN airport_id VARCHAR(100) NOT NULL;

GO

ALTER TABLE demographics ADD CONSTRAINT PK_demographics PRIMARY KEY (airport_id);

GO

ALTER TABLE airport_size ALTER COLUMN Locid VARCHAR(100) NOT NULL;

GO

ALTER TABLE airport_size ADD CONSTRAINT PK_airport_size PRIMARY KEY (Locid);

GO

ALTER TABLE airline ALTER COLUMN IATA_CODE_Reporting_Airline VARCHAR(100) NOT NULL;

GO

ALTER TABLE airline ADD CONSTRAINT PK_airline PRIMARY KEY (IATA_CODE_Reporting_Airline);



-- Assigning the foreign keys



GO

ALTER TABLE tail_number ADD CONSTRAINT FK_tail_number_aircraft_model FOREIGN KEY ([MFR MDL CODE]) REFERENCES aircraft_model (CODE);

GO

ALTER TABLE weather ADD CONSTRAINT FK_weather_airport_size FOREIGN KEY (locid) REFERENCES airport_size (Locid);

GO

ALTER TABLE delay_airports ADD CONSTRAINT FK_Delay_demographics FOREIGN KEY (Origin) REFERENCES demographics (airport_id);

GO

ALTER TABLE demographics ADD CONSTRAINT FK_demographics_airport_size FOREIGN KEY (airport_id) REFERENCES airport_size (Locid);

GO

ALTER TABLE delay_airports ADD CONSTRAINT FK_Delay_airport_size FOREIGN KEY (Origin) REFERENCES airport_size (Locid);

GO

ALTER TABLE runways_airport ADD CONSTRAINT FK_runways_airport_airport_size FOREIGN KEY (ARPT_ID) REFERENCES airport_size (Locid);

GO

ALTER TABLE delay_airports ADD CONSTRAINT FK_Delay_airline FOREIGN KEY (IATA_CODE_Reporting_Airline) REFERENCES airline (IATA_CODE_Reporting_Airline);

