-- Vehicle Positions Tabelle mit Spatial Index
CREATE TABLE vehicle_positions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  vehicle_id INT NOT NULL,
  lat DOUBLE NOT NULL,
  lon DOUBLE NOT NULL,
  speed DOUBLE NULL,
  heading DOUBLE NULL,
  ts TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
  moving BOOLEAN DEFAULT FALSE,
  location POINT SRID 4326 AS (ST_PointFromText(CONCAT('POINT(', lon, ' ', lat, ')'), 4326)) STORED,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
  INDEX idx_vehicle_ts (vehicle_id, ts DESC),
  SPATIAL INDEX sp_location (location),
  INDEX idx_moving (moving),
  INDEX idx_ts (ts)
);
