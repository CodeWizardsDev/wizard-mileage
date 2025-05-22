CREATE TABLE IF NOT EXISTS vehicle_mileage (
  plate VARCHAR(50) PRIMARY KEY,
  mileage DOUBLE NOT NULL DEFAULT 0,
  last_oil_change DOUBLE NOT NULL DEFAULT 0,
  last_oil_filter_change DOUBLE NOT NULL DEFAULT 0,
  last_air_filter_change DOUBLE NOT NULL DEFAULT 0,
  last_tire_change DOUBLE NOT NULL DEFAULT 0,
  last_brakes_change DOUBLE NOT NULL DEFAULT 0,
  brake_wear DOUBLE NOT NULL DEFAULT 0,
  last_clutch_change DOUBLE NOT NULL DEFAULT 0,
  clutch_wear DOUBLE NOT NULL DEFAULT 0
);
