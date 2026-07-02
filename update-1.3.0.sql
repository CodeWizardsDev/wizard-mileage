ALTER TABLE vehicle_mileage ADD COLUMN tire_wear_json TEXT DEFAULT '[]';
ALTER TABLE vehicle_mileage ADD COLUMN last_tire_change_json TEXT DEFAULT '[]';
ALTER TABLE vehicle_mileage ADD COLUMN brake_wear_json TEXT DEFAULT '[]';
ALTER TABLE vehicle_mileage ADD COLUMN last_brake_change_json TEXT DEFAULT '[]';