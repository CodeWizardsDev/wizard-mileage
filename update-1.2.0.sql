ALTER TABLE `vehicle_mileage` ADD COLUMN `last_suspension_change` DOUBLE NOT NULL DEFAULT 0

ALTER TABLE `vehicle_mileage` ADD COLUMN `suspension_wear` DOUBLE NOT NULL DEFAULT 0

ALTER TABLE `vehicle_mileage` ADD COLUMN `original_suspension_force` FLOAT DEFAULT NULL

ALTER TABLE `vehicle_mileage` ADD COLUMN `original_suspension_raise` FLOAT DEFAULT NULL

ALTER TABLE `vehicle_mileage` ADD COLUMN `last_spark_plug_change` DOUBLE NOT NULL DEFAULT 0

ALTER TABLE `vehicle_mileage` ADD COLUMN `spark_plug_wear` DOUBLE NOT NULL DEFAULT 0

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