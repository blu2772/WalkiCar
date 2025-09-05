# 🚗 WalkiCar - Voice-Enabled Car Tracking App

WalkiCar ist eine vollständige iOS-App mit Backend für Fahrzeug-Tracking und Voice-Chat zwischen Freunden. Die App ermöglicht es Benutzern, ihre Fahrzeuge zu verfolgen, mit Freunden zu kommunizieren und Live-Positionen auf einer Karte zu sehen.

## ✨ Features

### 🔐 Authentifizierung
- **Sign in with Apple** Integration
- JWT-basierte Authentifizierung mit Refresh-Tokens
- Sichere Benutzerverwaltung

### 👥 Freunde-System
- Benutzer suchen und Freundschaftsanfragen senden
- Freundschaftsanfragen akzeptieren/ablehnen
- Benutzer blockieren und Freunde entfernen
- Freundesliste verwalten

### 🎙️ Voice-Chat
- **Push-to-Talk** Funktionalität
- **WebRTC** für Audio-Übertragung
- Gruppenbasierte Voice-Chats
- **Musik-Priorität**: Spotify läuft in voller Qualität, Voice über iPhone-Lautsprecher
- Optionaler Hands-Free-Modus (mit Qualitätsabfall-Warnung)

### 🗺️ Car Map & Tracking
- **Garage**: Fahrzeuge hinzufügen, bearbeiten und verwalten
- **Live-Tracking**: Positionsupdates in Echtzeit
- **Sichtbarkeit**: Private, Freunde oder öffentlich
- **Tracking-Modi**: Aus, nur bei Bewegung, immer
- **Spatial Queries**: MySQL 8 mit räumlichen Indizes für Nearby-Suche

## 🏗️ Architektur

### Backend (NestJS/TypeScript)
- **REST API** mit Swagger-Dokumentation
- **WebSocket Gateway** für WebRTC Signaling
- **MySQL 8** mit Spatial-Support
- **Redis** für Caching und Rate-Limiting
- **coturn** TURN/STUN Server für WebRTC

### iOS App (SwiftUI)
- **iOS 16+** Unterstützung
- **SwiftUI** mit Combine für State Management
- **AudioRoutingManager** für Musik-Priorität
- **MapKit** für Kartenansicht
- **WebRTC** für Voice-Chat

## 🚀 Quick Start

### Voraussetzungen
- **Docker** und **Docker Compose**
- **Xcode 14+** für iOS-Entwicklung
- **Node.js 18+** für Backend-Entwicklung

### 1. Backend starten

```bash
# Repository klonen
git clone <repository-url>
cd WalkiCar

# Environment konfigurieren
cp backend/env.example backend/.env
# Bearbeiten Sie die .env-Datei mit Ihren Apple Developer Credentials

# Services starten
docker-compose up -d

# Datenbank-Schema importieren
mysql -h localhost -u walkicar -p walkicar < db/mysql/00_all.sql
```

### 2. iOS App konfigurieren

```bash
# iOS-Projekt öffnen
open "IOS App/WalkiCar/WalkiCar.xcodeproj"

# In Xcode:
# 1. Bundle Identifier setzen
# 2. Apple Developer Team auswählen
# 3. Sign in with Apple Capability aktivieren
# 4. Backend-URL in APIService anpassen
```

### 3. Services überprüfen

- **Backend API**: http://localhost:3000
- **API Dokumentation**: http://localhost:3000/api/docs
- **Health Check**: http://localhost:3000/health
- **MySQL**: localhost:3306
- **Redis**: localhost:6379
- **TURN Server**: localhost:3478

## 📱 iOS App Features

### Audio-Routing-Manager

Der `AudioRoutingManager` implementiert zwei Modi:

#### 🎵 Musik-Priorität (Standard)
- **Spotify** läuft in voller A2DP-Qualität
- **Voice-Chat** über iPhone-Lautsprecher
- **Kein HFP** (Hands-Free Profile) um Musik-Qualität zu erhalten
- **`.mixWithOthers`** Option aktiviert

#### 📞 Hands-Free-Priorität (Optional)
- Erlaubt **HFP** für Auto-Freisprechanlagen
- **Qualitätsabfall** bei Musik wird dokumentiert
- Umschaltbar in den Einstellungen

### Push-to-Talk Implementation

```swift
// PTT Button mit Long Press Gesture
.onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
  isPressingPTT = pressing
  if pressing {
    audioRoutingManager.startVoiceSession()
    // WebRTC: localTrack.unmute()
  } else {
    audioRoutingManager.endVoiceSession()
    // WebRTC: localTrack.mute()
  }
}, perform: {})
```

## 🔧 Backend API

### Authentifizierung
```bash
# Sign in with Apple
POST /api/v1/auth/apple
{
  "identityToken": "apple_identity_token",
  "displayName": "User Name",
  "avatarUrl": "https://example.com/avatar.jpg"
}

# Token refresh
POST /api/v1/auth/refresh
{
  "refreshToken": "jwt_refresh_token"
}
```

### Freunde
```bash
# Benutzer suchen
GET /api/v1/friends/search?query=john

# Freundschaftsanfrage senden
POST /api/v1/friends/requests
{
  "userId": 123
}

# Anfrage akzeptieren
PATCH /api/v1/friends/requests/456/accept
```

### Gruppen & Voice-Chat
```bash
# Gruppe erstellen
POST /api/v1/groups
{
  "name": "Car Enthusiasts",
  "description": "Group for car lovers",
  "is_public": true
}

# Gruppe beitreten
POST /api/v1/groups/123/join

# WebSocket für Voice-Chat
WS /voice
```

### Fahrzeuge & Tracking
```bash
# Fahrzeug hinzufügen
POST /api/v1/vehicles
{
  "name": "My Tesla",
  "brand": "Tesla",
  "model": "Model S",
  "color": "Blue",
  "visibility": "friends",
  "track_mode": "moving_only"
}

# Position senden
POST /api/v1/vehicles/123/positions
{
  "lat": 40.7128,
  "lon": -74.0060,
  "speed": 45.5,
  "heading": 180.0,
  "moving": true
}

# Nearby Fahrzeuge
GET /api/v1/map/nearby?centerLat=40.7128&centerLon=-74.0060&radius=5000
```

## 🗄️ Datenbank-Schema

### MySQL 8 mit Spatial Support

```sql
-- Räumliche Indizes für Nearby-Suche
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
);
```

### Beispiel-Queries

```sql
-- Nearby Fahrzeuge (5km Radius)
SELECT v.*, vp.lat, vp.lon, vp.speed, vp.moving
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
WHERE ST_Distance_Sphere(
  ST_PointFromText(CONCAT('POINT(', vp.lon, ' ', vp.lat, ')'), 4326),
  ST_PointFromText('POINT(-74.0060 40.7128)', 4326)
) <= 5000
AND v.track_mode != 'off'
ORDER BY vp.ts DESC;

-- Nur bewegte Fahrzeuge
SELECT * FROM vehicle_positions 
WHERE moving = TRUE 
AND ts > DATE_SUB(NOW(), INTERVAL 5 MINUTE);
```

## 🌐 WebRTC Signaling

### Signaling-Server (WebSocket)

```typescript
// Client verbindet sich
WS /voice
Authorization: Bearer <jwt_token>

// Raum beitreten
{
  "type": "join-room",
  "data": { "groupId": "123" }
}

// WebRTC Signaling
{
  "type": "offer",
  "data": { "sdp": "..." },
  "targetUserId": "456"
}

// Push-to-Talk
{
  "type": "unmute",
  "data": { "groupId": "123" }
}
```

### TURN-Server Konfiguration

```bash
# coturn Konfiguration
listening-port=3478
user=turnuser:turnpassword
realm=walkicar
relay-range=49152-65535
```

## 🔒 Sicherheit & Privacy

### Datenschutz-Features
- **Feingranulare Sichtbarkeit**: Private, Freunde, Öffentlich
- **Tracking-Modi**: Aus, nur bei Bewegung, immer
- **Freundschafts-basierte Filter**: Nur Freunde sehen private Fahrzeuge
- **Rate-Limiting**: 60 Requests/Minute für Positionsupdates

### Authentifizierung
- **Apple Sign In** für sichere Authentifizierung
- **JWT Tokens** mit kurzer Lebensdauer (15 Min)
- **Refresh Tokens** für verlängerte Sessions
- **WebSocket Authentication** für Voice-Chat

## 🧪 Testing

### Backend Tests
```bash
cd backend
npm test
npm run test:e2e
npm run test:cov
```

### iOS Tests
```bash
# In Xcode: Cmd+U für Unit Tests
# UI Tests für Voice-Chat und Map-Funktionalität
```

## 📊 Monitoring & Logging

### Health Checks
- **API Health**: `GET /health`
- **Database**: Connection Pool Status
- **Redis**: Cache Hit Rate
- **TURN Server**: Active Connections

### Logging
- **Structured Logging** ohne PII
- **Request IDs** für Tracing
- **WebRTC Signaling** Events
- **Rate Limiting** Alerts

## 🚀 Deployment

### Produktions-Umgebung

```bash
# Environment Variables
NODE_ENV=production
MYSQL_HOST=your-mysql-host
REDIS_HOST=your-redis-host
JWT_SECRET=your-production-secret
APPLE_TEAM_ID=your-apple-team-id
APPLE_KEY_ID=your-apple-key-id
APPLE_PRIVATE_KEY=your-apple-private-key

# SSL/TLS Konfiguration
# Nginx Reverse Proxy mit Let's Encrypt
# TURN Server mit SSL-Zertifikaten
```

### Docker Compose Production
```yaml
# Produktions-optimierte Konfiguration
# SSL-Zertifikate
# Load Balancing
# Monitoring Stack (Prometheus/Grafana)
```

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/amazing-feature`)
3. Commits mit aussagekräftigen Messages
4. Tests schreiben und ausführen
5. Pull Request erstellen

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei für Details.

## 🆘 Support

Bei Problemen oder Fragen:
- **Issues**: GitHub Issues verwenden
- **Dokumentation**: `/docs` Ordner
- **API Docs**: http://localhost:3000/api/docs

---

**WalkiCar** - Verbinde dich mit deinen Freunden, während du fährst! 🚗💨