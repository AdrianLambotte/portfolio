-- CREATE DATABASE TFE_staging
USE TFE_staging

GO

-- SELECT * FROM runways_airport
-- SELECT * FROM delay_airports 
-- SELECT * FROM demographics
-- SELECT * FROM tail_number 
-- SELECT * FROM aircraft_model 
-- SELECT * FROM weather
-- SELECT * FROM airline
-- SELECT * FROM airport_size


-- Assigning the primary keys


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
ALTER TABLE tail_number ADD CONSTRAINT FK_tail_number_aircraft_model FOREIGN KEY ([MFR MDL CODE]) REFERENCES aircraft_model (CODE)

GO
ALTER TABLE weather ADD CONSTRAINT FK_weather_airport_size FOREIGN KEY (locid) REFERENCES airport_size (Locid)

GO
ALTER TABLE delay_airports ADD CONSTRAINT FK_delay_airports_demographics FOREIGN KEY (Origin) REFERENCES demographics (airport_id)

GO
ALTER TABLE demographics ADD CONSTRAINT FK_demographics_airport_size FOREIGN KEY (airport_id) REFERENCES airport_size (Locid)

GO
ALTER TABLE delay_airports ADD CONSTRAINT FK_delay_airports_airport_size FOREIGN KEY (Origin) REFERENCES airport_size (Locid)

GO
ALTER TABLE runways_airport ADD CONSTRAINT FK_runways_airport_airport_size FOREIGN KEY (ARPT_ID) REFERENCES airport_size (Locid)

GO
ALTER TABLE delay_airports ADD CONSTRAINT FK_delay_airports_airline FOREIGN KEY (IATA_CODE_Reporting_Airline) REFERENCES airline (IATA_CODE_Reporting_Airline)


