-- WalkiCar Database Schema - Complete Import
-- Execute this file to create the entire database schema

-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS walkicar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE walkicar;

-- Import all table definitions in correct order
SOURCE 01_users.sql;
SOURCE 02_friendships.sql;
SOURCE 03_groups.sql;
SOURCE 04_vehicles.sql;
SOURCE 05_refresh_tokens.sql;

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
