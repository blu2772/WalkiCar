-- Vehicles table
CREATE TABLE vehicles (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  brand VARCHAR(50),
  model VARCHAR(50),
  color VARCHAR(30),
  ble_identifier VARCHAR(255),
  visibility ENUM('private', 'friends', 'public') DEFAULT 'private',
  track_mode ENUM('off', 'moving_only', 'always') DEFAULT 'off',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_vehicles (user_id),
  INDEX idx_visibility (visibility),
  INDEX idx_track_mode (track_mode),
  INDEX idx_ble_identifier (ble_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vehicle positions table with spatial indexing
CREATE TABLE vehicle_positions (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  vehicle_id INT NOT NULL,
  lat DOUBLE NOT NULL,
  lon DOUBLE NOT NULL,
  speed DOUBLE NULL,
  heading DOUBLE NULL,
  moving BOOLEAN DEFAULT FALSE,
  ts TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
  location POINT SRID 4326 AS (ST_PointFromText(CONCAT('POINT(', lon, ' ', lat, ')'), 4326)) STORED,
  
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
  INDEX idx_vehicle_ts (vehicle_id, ts DESC),
  INDEX idx_moving (moving),
  SPATIAL INDEX sp_location (location)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
