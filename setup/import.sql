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
  clutch_wear DOUBLE NOT NULL DEFAULT 0,
  original_drive_force FLOAT DEFAULT NULL,
  last_suspension_change DOUBLE NOT NULL DEFAULT 0,
  suspension_wear DOUBLE NOT NULL DEFAULT 0,
  original_suspension_force FLOAT DEFAULT NULL,
  original_suspension_raise FLOAT DEFAULT NULL,
  last_spark_plug_change DOUBLE NOT NULL DEFAULT 0,
  spark_plug_wear DOUBLE NOT NULL DEFAULT 0
);
CREATE INDEX idx_vehicle_mileage_plate ON vehicle_mileage(plate);
CREATE INDEX idx_vehicle_status ON vehicle_mileage(plate, mileage);

CREATE TABLE IF NOT EXISTS mileage_settings (
  player_id VARCHAR(50) PRIMARY KEY,
  mileage_visible BOOLEAN NOT NULL DEFAULT 1,
  mileage_size FLOAT NOT NULL DEFAULT 1.0,
  checkwear_size FLOAT NOT NULL DEFAULT 1.0,
  mileage_pos_x FLOAT NOT NULL DEFAULT 0.0,
  mileage_pos_y FLOAT NOT NULL DEFAULT 0.0,
  checkwear_pos_x FLOAT NOT NULL DEFAULT 0.0,
  checkwear_pos_y FLOAT NOT NULL DEFAULT 0.0
);