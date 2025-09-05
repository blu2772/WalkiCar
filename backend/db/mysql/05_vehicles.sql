-- Vehicles Tabelle
CREATE TABLE vehicles (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  brand VARCHAR(50),
  model VARCHAR(50),
  color VARCHAR(30),
  ble_identifier VARCHAR(100),
  visibility ENUM('private', 'friends', 'public') DEFAULT 'private',
  track_mode ENUM('off', 'moving_only', 'always') DEFAULT 'off',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_vehicles (user_id),
  INDEX idx_visibility (visibility),
  INDEX idx_track_mode (track_mode),
  INDEX idx_ble_identifier (ble_identifier)
);
