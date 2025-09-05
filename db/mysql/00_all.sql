-- WalkiCar Database Schema - Complete Import
-- Execute this file to create the entire database schema

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS walkicar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE walkicar;

-- Users table
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  apple_sub VARCHAR(255) UNIQUE NULL,
  email VARCHAR(255) UNIQUE NULL,
  password_hash VARCHAR(255) NULL,
  display_name VARCHAR(100) NOT NULL,
  avatar_url VARCHAR(500),
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  INDEX idx_apple_sub (apple_sub),
  INDEX idx_email (email),
  INDEX idx_display_name (display_name),
  CONSTRAINT chk_auth_method CHECK (
    (apple_sub IS NOT NULL AND password_hash IS NULL) OR 
    (email IS NOT NULL AND password_hash IS NOT NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Friendships table
CREATE TABLE friendships (
  id INT PRIMARY KEY AUTO_INCREMENT,
  user_id INT NOT NULL,
  friend_id INT NOT NULL,
  status ENUM('pending', 'accepted', 'blocked') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (friend_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_friendship (user_id, friend_id),
  INDEX idx_user_status (user_id, status),
  INDEX idx_friend_status (friend_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Groups table
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Group members table
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
  INDEX idx_vehicle_ts (vehicle_id, ts DESC),
  INDEX idx_moving (moving),
  INDEX idx_lat_lon (lat, lon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Refresh tokens table
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create sample data for development
INSERT INTO users (apple_sub, display_name, avatar_url) VALUES
  ('sample_user_1', 'Tim', 'https://example.com/avatar1.jpg'),
  ('sample_user_2', 'Lauren', 'https://example.com/avatar2.jpg'),
  ('sample_user_3', 'Drew', 'https://example.com/avatar3.jpg'),
  ('sample_user_4', 'Nicole', 'https://example.com/avatar4.jpg');

-- Sample friendships
INSERT INTO friendships (user_id, friend_id, status) VALUES
  (1, 2, 'accepted'),
  (1, 3, 'accepted'),
  (2, 3, 'accepted'),
  (1, 4, 'pending');

-- Sample groups
INSERT INTO groups (owner_id, name, description, is_public) VALUES
  (1, 'Car Enthusiasts', 'Group for car lovers', TRUE),
  (2, 'Weekend Drivers', 'Private group for weekend trips', FALSE);

-- Sample group members
INSERT INTO group_members (group_id, user_id, role) VALUES
  (1, 1, 'owner'),
  (1, 2, 'member'),
  (1, 3, 'member'),
  (2, 2, 'owner'),
  (2, 1, 'member');

-- Sample vehicles
INSERT INTO vehicles (user_id, name, brand, model, color, ble_identifier, visibility, track_mode) VALUES
  (1, 'Cupue', 'Tesla', 'Model S', 'Blue', 'BLE_CUPUE_001', 'friends', 'moving_only'),
  (1, 'SUV', 'BMW', 'X5', 'White', 'BLE_SUV_002', 'public', 'always'),
  (1, 'Gnoross', 'Porsche', '911', 'Gray', 'BLE_GNOROSS_003', 'private', 'off'),
  (2, 'Lauren\'s Car', 'Audi', 'A4', 'Red', 'BLE_LAUREN_001', 'friends', 'moving_only');

-- Sample vehicle positions
INSERT INTO vehicle_positions (vehicle_id, lat, lon, speed, heading, moving) VALUES
  (1, 40.7128, -74.0060, 45.5, 180.0, TRUE),
  (2, 40.7589, -73.9851, 0.0, 0.0, FALSE),
  (3, 40.7505, -73.9934, 30.2, 90.0, TRUE),
  (4, 40.7614, -73.9776, 15.8, 270.0, TRUE);

-- Show created tables
SHOW TABLES;

-- Show sample data
SELECT 'Users:' as info;
SELECT * FROM users;

SELECT 'Friendships:' as info;
SELECT * FROM friendships;

SELECT 'Groups:' as info;
SELECT * FROM groups;

SELECT 'Vehicles:' as info;
SELECT * FROM vehicles;
