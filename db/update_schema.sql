-- WalkiCar Database Schema Update
-- Nur die neuen Tabellen und Spalten hinzufügen

-- Erweitere locations Tabelle um neue Spalten
ALTER TABLE locations 
ADD COLUMN IF NOT EXISTS is_live BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS is_parked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS bluetooth_connected BOOLEAN DEFAULT FALSE;

-- Füge neue Indizes hinzu
CREATE INDEX IF NOT EXISTS idx_live_locations ON locations (is_live, timestamp);
CREATE INDEX IF NOT EXISTS idx_parked_locations ON locations (is_parked, timestamp);

-- Erstelle parked_locations Tabelle (falls nicht vorhanden)
CREATE TABLE IF NOT EXISTS parked_locations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    car_id INT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy FLOAT,
    parked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_live_update TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_car_parked (user_id, car_id),
    INDEX idx_user_parked (user_id),
    INDEX idx_car_parked (car_id),
    INDEX idx_parked_coords (latitude, longitude)
);

-- Erstelle location_history Tabelle (falls nicht vorhanden)
CREATE TABLE IF NOT EXISTS location_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    car_id INT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy FLOAT,
    speed FLOAT,
    heading FLOAT,
    altitude FLOAT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE SET NULL,
    INDEX idx_user_history (user_id, timestamp),
    INDEX idx_car_history (car_id, timestamp),
    INDEX idx_history_time (timestamp)
);

-- Prüfe ob alle Tabellen existieren
SHOW TABLES LIKE 'parked_locations';
SHOW TABLES LIKE 'location_history';
SHOW COLUMNS FROM locations LIKE 'is_live';
SHOW COLUMNS FROM locations LIKE 'is_parked';
SHOW COLUMNS FROM locations LIKE 'bluetooth_connected';
