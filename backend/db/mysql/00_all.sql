-- WalkiCar Database Schema
-- Erstellt alle Tabellen für die WalkiCar App

-- Users Tabelle
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  apple_sub VARCHAR(255) UNIQUE NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  avatar_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_apple_sub (apple_sub),
  INDEX idx_display_name (display_name)
);

-- Friendships Tabelle
CREATE TABLE friendships (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  friend_id INT NOT NULL,
  status ENUM('pending', 'accepted', 'blocked') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (friend_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_pair (LEAST(user_id, friend_id), GREATEST(user_id, friend_id)),
  INDEX idx_user_status (user_id, status),
  INDEX idx_friend_status (friend_id, status)
);

-- Groups Tabelle
CREATE TABLE groups (
  id INT PRIMARY KEY AUTO_INCREMENT,
  owner_id INT NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_public BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_owner (owner_id),
  INDEX idx_public (is_public),
  INDEX idx_name (name)
);

-- Group Members Tabelle
CREATE TABLE group_members (
  id INT PRIMARY KEY AUTO_INCREMENT,
  group_id INT NOT NULL,
  user_id INT NOT NULL,
  role ENUM('owner', 'mod', 'member') DEFAULT 'member',
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_member (group_id, user_id),
  INDEX idx_group_role (group_id, role),
  INDEX idx_user_groups (user_id)
);

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

-- Refresh Tokens Tabelle
CREATE TABLE refresh_tokens (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  token VARCHAR(500) UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_token (user_id),
  INDEX idx_token (token),
  INDEX idx_expires (expires_at)
);
