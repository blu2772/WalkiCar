-- WalkiCar Database Schema Update - Prüfung und sichere Updates
-- Prüfe welche Spalten bereits existieren und füge nur fehlende hinzu

-- Prüfe ob Spalten existieren und füge sie nur hinzu wenn sie nicht existieren
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'walkicar_db' 
     AND TABLE_NAME = 'locations' 
     AND COLUMN_NAME = 'is_live') = 0,
    'ALTER TABLE locations ADD COLUMN is_live BOOLEAN DEFAULT TRUE',
    'SELECT "Spalte is_live existiert bereits" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'walkicar_db' 
     AND TABLE_NAME = 'locations' 
     AND COLUMN_NAME = 'is_parked') = 0,
    'ALTER TABLE locations ADD COLUMN is_parked BOOLEAN DEFAULT FALSE',
    'SELECT "Spalte is_parked existiert bereits" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
     WHERE TABLE_SCHEMA = 'walkicar_db' 
     AND TABLE_NAME = 'locations' 
     AND COLUMN_NAME = 'bluetooth_connected') = 0,
    'ALTER TABLE locations ADD COLUMN bluetooth_connected BOOLEAN DEFAULT FALSE',
    'SELECT "Spalte bluetooth_connected existiert bereits" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Prüfe ob Indizes existieren und füge sie nur hinzu wenn sie nicht existieren
SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = 'walkicar_db' 
     AND TABLE_NAME = 'locations' 
     AND INDEX_NAME = 'idx_live_locations') = 0,
    'CREATE INDEX idx_live_locations ON locations (is_live, timestamp)',
    'SELECT "Index idx_live_locations existiert bereits" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS 
     WHERE TABLE_SCHEMA = 'walkicar_db' 
     AND TABLE_NAME = 'locations' 
     AND INDEX_NAME = 'idx_parked_locations') = 0,
    'CREATE INDEX idx_parked_locations ON locations (is_parked, timestamp)',
    'SELECT "Index idx_parked_locations existiert bereits" as message'
));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Erstelle parked_locations Tabelle nur wenn sie nicht existiert
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

-- Erstelle location_history Tabelle nur wenn sie nicht existiert
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

-- Erweitere cars Tabelle um audio_device_names für Audio-Route-Überwachung
ALTER TABLE cars ADD COLUMN IF NOT EXISTS audio_device_names JSON DEFAULT NULL COMMENT 'Array von Audio-Geräte-Namen für automatische Auto-Aktivierung';

-- Erstelle Index für bessere Performance bei Audio-Geräte-Suche
CREATE INDEX IF NOT EXISTS idx_cars_audio_device_names ON cars((CAST(audio_device_names AS CHAR(255) ARRAY)));

-- Zeige aktuelle Struktur der locations Tabelle
DESCRIBE locations;

-- Zeige alle Tabellen
SHOW TABLES;
