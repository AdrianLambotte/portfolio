
-- CREATE DATABASE TFE_gold
USE TFE_gold


GO

DROP TABLE IF EXISTS fact_delay_weather
DROP TABLE IF EXISTS fact_demographics
DROP TABLE IF EXISTS dim_runway
DROP TABLE IF EXISTS dim_airport
DROP TABLE IF EXISTS dim_aircraft
DROP TABLE IF EXISTS dim_airlines
DROP TABLE IF EXISTS dim_date
DROP TABLE IF EXISTS dim_time
DROP TABLE IF EXISTS dim_category_weather_wind_cloud
DROP TABLE IF EXISTS dim_category_weather_temp_precip




GO

-- Creating the dimension tables


--dim_airport
CREATE TABLE dim_airport(

locid VARCHAR(100) NOT NULL,
airport_name VARCHAR(100),
city VARCHAR(100),
state VARCHAR(100),
hub VARCHAR(100),
enplanement_2024 INT


CONSTRAINT PK_dim_airport PRIMARY KEY (locid)

);


--dim_runway
CREATE TABLE dim_runway(

runway_id INT IDENTITY(1,1),
runway_name VARCHAR(100),
runway_length DECIMAL(10,2),
runway_width DECIMAL(10,2),
surface_type VARCHAR(100),
condition VARCHAR(100),
runway_length_code VARCHAR(100),
locid VARCHAR(100) 


CONSTRAINT PK_dim_runway PRIMARY KEY (runway_id),
CONSTRAINT FK_runway_depuis_airport FOREIGN KEY (locid) REFERENCES dim_airport (locid)

);



--dim_aircraft
CREATE TABLE dim_aircraft(

aircraft_registration_number VARCHAR(100) NOT NULL,
year_mfr INT,
mfr VARCHAR(100),
model VARCHAR(100),
number_seats INT


CONSTRAINT PK_dim_aircraft PRIMARY KEY (aircraft_registration_number)

);


--dim_airlines
CREATE TABLE dim_airlines(

IATA_code VARCHAR(100) NOT NULL,
airline_name VARCHAR(100)


CONSTRAINT PK_dim_airlines PRIMARY KEY (IATA_code)

);


--dim_date 
CREATE TABLE dim_date(

datekey INT NOT NULL,
full_date DATE,
year INT,
month INT,
day INT,
day_of_week VARCHAR(100)



CONSTRAINT PK_dim_date PRIMARY KEY (datekey)

);


--dim_time
CREATE TABLE dim_time(

timekey INT NOT NULL,
full_time TIME,
hour INT,
minute INT


CONSTRAINT PK_dim_time PRIMARY KEY (timekey)

);




--dim_category_weather_temp_precip

CREATE TABLE dim_category_weather_temp_precip(
category_weather_temp_precip_id INT IDENTITY(1,1),
temperature_category VARCHAR(100),
precipitation_category VARCHAR(100),
precipitation_type VARCHAR(100),
description VARCHAR(255)

CONSTRAINT PK_dim_category_weather_temp_precip PRIMARY KEY (category_weather_temp_precip_id)
);


--dim_category_weather_wind_cloud
CREATE TABLE dim_category_weather_wind_cloud(
category_weather_wind_cloud_id INT IDENTITY(1,1),
wind_speed_category VARCHAR(100),
wind_gusts_category VARCHAR(100),
cloud_low_category VARCHAR(100),
cloud_mid_category VARCHAR(100),
description VARCHAR(255)

CONSTRAINT PK_dim_category_weather_wind_cloud PRIMARY KEY (category_weather_wind_cloud_id)
);


-- Creating fact tables


--fact_demographics
CREATE TABLE fact_demographics(

demographics_id VARCHAR(100),
population INT,
median_household_income_per_year INT,
pop_25plus INT,
got_bachelors_diploma_count DECIMAL(10,2),
statistical_area INT,
area_type VARCHAR(100),

locid VARCHAR(100) 


CONSTRAINT PK_fact_demographics PRIMARY KEY (demographics_id),
CONSTRAINT FK_demographics_depuis_airport FOREIGN KEY (locid) REFERENCES dim_airport (locid)

);





--fact_delay_weather
CREATE TABLE fact_delay_weather(

delay_id INT IDENTITY(1,1),

departure_locid VARCHAR(100),
aircraft_registration_number VARCHAR(100),
IATA_code VARCHAR(100),
datekey INT,
taxi_out INT,
wheels_off INT,
crs_departure_time INT,
departure_time INT,
wheels_on INT,
taxi_in INT,
crs_arrival_time INT,
arrival_time INT,

departure_delay INT,
arrival_delay INT,
departure_delay_positive INT,
arrival_delay_positive INT,
departure_early INT,
arrival_early INT,
cancelled BIT,
cancellation_code VARCHAR(100),
diverted BIT,
crs_elapsed_time INT,
actual_elapsed_time INT,
distance_km DECIMAL(10,3),
carrier_delay INT,
weather_delay INT,
NAS_delay INT,
security_delay INT,
late_aircraft_delay INT,

weather_code INT,
precipitation DECIMAL(10,1),
rain DECIMAL(10,1),
temperature DECIMAL(10,2),
snow_depth_m DECIMAL(10,2),
snow_fall_cm DECIMAL(10,2),
cloud_cover_low INT,
cloud_cover_mid INT,
wind_speed DECIMAL(10,5),
wind_gusts DECIMAL(10,2),
wind_direction DECIMAL(10,4),
category_weather_temp_precip_id INT,
category_weather_wind_cloud_id INT


CONSTRAINT PK_fact_delay_weather PRIMARY KEY (delay_id),

CONSTRAINT FK_category_weather_temp_precip FOREIGN KEY (category_weather_temp_precip_id) REFERENCES dim_category_weather_temp_precip (category_weather_temp_precip_id),
CONSTRAINT FK_category_weather_wind_cloud FOREIGN KEY (category_weather_wind_cloud_id) REFERENCES dim_category_weather_wind_cloud (category_weather_wind_cloud_id),

CONSTRAINT FK_departure_locid FOREIGN KEY (departure_locid) REFERENCES dim_airport (locid),
CONSTRAINT FK_aircraft_registration_number FOREIGN KEY (aircraft_registration_number) REFERENCES dim_aircraft (aircraft_registration_number),
CONSTRAINT FK_IATA_code FOREIGN KEY (IATA_code) REFERENCES dim_airlines (IATA_code),
CONSTRAINT FK_datekey FOREIGN KEY (datekey) REFERENCES dim_date (datekey),
CONSTRAINT FK_wheels_off FOREIGN KEY (wheels_off) REFERENCES dim_time (timekey),
CONSTRAINT FK_crs_departure_time FOREIGN KEY (crs_departure_time) REFERENCES dim_time (timekey),
CONSTRAINT FK_departure_time FOREIGN KEY (departure_time) REFERENCES dim_time (timekey),
CONSTRAINT FK_wheels_on FOREIGN KEY (wheels_on) REFERENCES dim_time (timekey),
CONSTRAINT FK_crs_arrival_time FOREIGN KEY (crs_arrival_time) REFERENCES dim_time (timekey),
CONSTRAINT FK_arrival_time FOREIGN KEY (arrival_time) REFERENCES dim_time (timekey)

);






