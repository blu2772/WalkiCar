-- Beispiel Queries für Spatial Search

-- 1. Fahrzeuge in 5km Radius finden
-- Parameter: center_lat, center_lon, radius_meters
SELECT 
  v.id,
  v.name,
  v.brand,
  v.model,
  v.color,
  v.visibility,
  ST_Distance_Sphere(
    ST_PointFromText(CONCAT('POINT(', vp.lon, ' ', vp.lat, ')'), 4326),
    ST_PointFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326)
  ) AS distance_meters,
  vp.lat,
  vp.lon,
  vp.speed,
  vp.heading,
  vp.moving,
  vp.ts
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
WHERE v.visibility IN ('public', 'friends')
  AND v.track_mode != 'off'
  AND vp.ts >= DATE_SUB(NOW(), INTERVAL 5 MINUTE) -- Nur aktuelle Positionen
  AND ST_Distance_Sphere(
    ST_PointFromText(CONCAT('POINT(', vp.lon, ' ', vp.lat, ')'), 4326),
    ST_PointFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326)
  ) <= ?
ORDER BY distance_meters;

-- 2. Nur bewegte Fahrzeuge finden
SELECT 
  v.id,
  v.name,
  vp.lat,
  vp.lon,
  vp.speed,
  vp.heading,
  vp.ts
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
WHERE v.track_mode = 'moving_only'
  AND vp.moving = TRUE
  AND vp.ts >= DATE_SUB(NOW(), INTERVAL 2 MINUTE)
ORDER BY vp.ts DESC;

-- 3. Fahrzeuge von Freunden finden
SELECT 
  v.id,
  v.name,
  v.brand,
  v.model,
  vp.lat,
  vp.lon,
  vp.speed,
  vp.heading,
  vp.moving,
  vp.ts
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
JOIN friendships f ON v.user_id = f.friend_id
WHERE f.user_id = ? -- Aktueller User
  AND f.status = 'accepted'
  AND v.visibility IN ('friends', 'public')
  AND vp.ts >= DATE_SUB(NOW(), INTERVAL 5 MINUTE)
ORDER BY vp.ts DESC;

-- 4. Bounding Box Query für Map View
-- Parameter: min_lat, max_lat, min_lon, max_lon
SELECT 
  v.id,
  v.name,
  v.brand,
  v.model,
  v.color,
  vp.lat,
  vp.lon,
  vp.speed,
  vp.heading,
  vp.moving,
  vp.ts
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
WHERE vp.lat BETWEEN ? AND ?
  AND vp.lon BETWEEN ? AND ?
  AND v.visibility IN ('public', 'friends')
  AND vp.ts >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)
ORDER BY vp.ts DESC;
