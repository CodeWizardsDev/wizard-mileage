CREATE INDEX idx_vehicle_mileage_plate ON vehicle_mileage(plate);
CREATE INDEX idx_vehicle_status ON vehicle_mileage(plate, mileage);