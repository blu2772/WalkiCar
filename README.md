# WalkiCar - Vollständige iOS & Backend Lösung

Eine moderne Walkie-Talkie-App für Fahrzeugfahrer mit Voice-Chat, Live-Tracking und Freundesnetzwerk.

## 🚗 Features

### Kernfunktionen
- **Sign in with Apple** - Sichere Authentifizierung
- **Freunde-Management** - Suche, Anfragen senden/akzeptieren, Blockieren
- **Gruppen mit Voice-Chat** - Permanente Voice-Channels mit Push-to-Talk
- **Car Map** - Live-Fahrzeug-Tracking mit MapKit
- **Garage** - Fahrzeug-Management mit Sichtbarkeits-Einstellungen

### Audio-System (Musik-Priorität)
- **Spotify bleibt in A2DP-Qualität** während Voice-Chat
- **Voice-Audio über iPhone-Speaker** (konfigurierbar)
- **Push-to-Talk** mit visueller Rückmeldung
- **Zwei Modi**: Musik-Priorität (Standard) und Freisprech-Priorität

## 🏗️ Architektur

### Backend (NestJS + TypeScript)
- **Auth Service**: Sign in with Apple → JWT Tokens
- **Friends Service**: Freundesnetzwerk-Management
- **Groups Service**: Gruppen mit permanenten Voice-Channels
- **Vehicles Service**: Fahrzeug-Tracking mit Spatial Queries
- **Voice Service**: LiveKit Integration für WebRTC

### iOS (SwiftUI + iOS 16+)
- **AudioRoutingManager**: Musik-Priorität während Voice-Chat
- **MapKit Integration**: Live-Fahrzeug-Tracking mit Clustering
- **LiveKit WebRTC**: Push-to-Talk Voice-Chat
- **Combine**: Reaktive Datenarchitektur

### Infrastructure
- **MySQL 8**: Mit Spatial Index für Geo-Queries
- **Redis**: Rate Limiting und Caching
- **LiveKit Server**: SFU für WebRTC
- **coturn**: STUN/TURN Server
- **Docker Compose**: Vollständige Entwicklungsumgebung

## 🚀 Setup

### 1. Backend starten
```bash
cd backend
cp env.example .env
# Bearbeite .env mit deinen Werten
docker-compose up -d
```

### 2. MySQL Schema importieren
```bash
mysql -u root -p walkicar < db/mysql/00_all.sql
```

### 3. iOS App öffnen
```bash
cd "IOS App/WalkiCar"
open WalkiCar.xcodeproj
```

### 4. Dependencies installieren
- LiveKit SDK wird automatisch über Swift Package Manager geladen
- Backend Dependencies werden über npm installiert

## 📱 iOS App Features

### Welcome Screen
- Sign in with Apple Integration
- Automatische Token-Verwaltung
- JWT-basierte Authentifizierung

### Map View
- **Live-Fahrzeug-Tracking** mit MapKit
- **Filter**: Nur Freunde, Nur bewegte Fahrzeuge
- **Spatial Queries**: 5km Radius-Suche
- **Annotation Clustering** für Performance

### Groups & Voice Chat
- **Gruppen erstellen/beitreten**
- **Permanente Voice-Channels** pro Gruppe
- **Push-to-Talk** mit Hold-to-Talk Button
- **LiveKit WebRTC** für niedrige Latenz

### Garage
- **Fahrzeuge hinzufügen/verwalten**
- **Sichtbarkeit**: Private, Freunde, Öffentlich
- **Tracking-Modi**: Aus, Nur bei Bewegung, Immer
- **BLE-Identifier** für Hardware-Integration

### Settings
- **Audio-Modi umschalten**
- **Privacy-Einstellungen**
- **Freunde-Management**
- **Benachrichtigungen**

## 🔊 Audio-Routing System

### Musik-Priorität (Standard)
```swift
// AudioSession konfigurieren
try audioSession.setCategory(
  .playAndRecord,
  mode: .voiceChat,
  options: [.mixWithOthers, .defaultToSpeaker]
)
// WICHTIG: Keine .allowBluetooth Option!
```

**Verhalten:**
- Spotify bleibt in **A2DP-Qualität**
- Voice-Audio über **iPhone-Speaker**
- Kein HFP-Telefonmodus
- Musik wird nicht unterbrochen

### Freisprech-Priorität (Optional)
```swift
// HFP-Modus aktivieren
try audioSession.setCategory(
  .playAndRecord,
  mode: .voiceChat,
  options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
)
```

**Verhalten:**
- HFP-Modus aktiviert
- Qualitätsabfall bei Musik (bekannt/akzeptiert)
- Voice über Auto-Freisprechanlage

## 🗄️ Datenbank Schema

### Tabellen
- `users` - Benutzer mit Apple Sub
- `friendships` - Freundesbeziehungen mit Status
- `groups` - Gruppen mit Owner/Mod/Member Rollen
- `group_members` - Gruppenmitgliedschaften
- `vehicles` - Fahrzeuge mit Sichtbarkeit/Tracking
- `vehicle_positions` - Positionsdaten mit Spatial Index
- `refresh_tokens` - JWT Refresh Token Management

### Spatial Queries
```sql
-- Fahrzeuge in 5km Radius finden
SELECT v.*, ST_Distance_Sphere(
  ST_PointFromText(CONCAT('POINT(', vp.lon, ' ', vp.lat, ')'), 4326),
  ST_PointFromText(CONCAT('POINT(', ?, ' ', ?, ')'), 4326)
) AS distance_meters
FROM vehicles v
JOIN vehicle_positions vp ON v.id = vp.vehicle_id
WHERE ST_Distance_Sphere(...) <= ?
```

## 🔧 API Endpoints

### Auth
- `POST /auth/apple` - Sign in with Apple
- `POST /auth/refresh` - Token Refresh
- `GET /auth/me` - Current User

### Friends
- `GET /friends` - Freundesliste
- `POST /friends/requests` - Freundschaftsanfrage senden
- `POST /friends/requests/:id/respond` - Anfrage beantworten
- `DELETE /friends/:id` - Freund entfernen

### Groups & Voice
- `POST /groups` - Gruppe erstellen
- `GET /groups` - Gruppen auflisten
- `POST /groups/:id/join` - Gruppe beitreten
- `GET /voice/groups/:id/token` - LiveKit Join Token

### Vehicles & Map
- `POST /vehicles` - Fahrzeug hinzufügen
- `GET /vehicles/mine` - Eigene Fahrzeuge
- `POST /vehicles/:id/positions` - Position senden
- `GET /vehicles/map/nearby` - Nahe Fahrzeuge

## 🐳 Docker Services

### Backend Stack
- **api**: NestJS Backend (Port 3000)
- **mysql**: MySQL 8 mit Spatial Support (Port 3306)
- **redis**: Redis für Caching (Port 6379)
- **livekit**: WebRTC SFU Server (Port 7880)
- **turn**: coturn STUN/TURN Server (Port 3478)

### Environment Variables
```bash
# Database
MYSQL_HOST=localhost
MYSQL_DB=walkicar
MYSQL_USER=walkicar
MYSQL_PASSWORD=walkicar123

# JWT
JWT_SECRET=your-super-secret-jwt-key
JWT_EXPIRES_IN=15m

# Apple Sign In
APPLE_TEAM_ID=your-apple-team-id
APPLE_KEY_ID=your-apple-key-id
APPLE_PRIVATE_KEY=your-apple-private-key

# LiveKit
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_WS_URL=ws://localhost:7880
```

## 🧪 Testing

### Backend Tests
```bash
cd backend
npm test
npm run test:e2e
```

### iOS Tests
```bash
# In Xcode: Cmd+U für Unit Tests
# UI Tests für kritische Flows
```

## 📚 Dokumentation

- **API Docs**: http://localhost:3000/api/docs (Swagger)
- **Spatial Queries**: `db/mysql/08_spatial_queries.sql`
- **Audio Routing**: `AudioRoutingManager.swift`

## 🔒 Sicherheit

- **JWT Tokens** mit kurzer Lebensdauer (15min)
- **Refresh Tokens** für sichere Erneuerung
- **Rate Limiting** für Positionsupdates (60 req/min)
- **Privacy Filter** serverseitig
- **Apple Sign In** für sichere Authentifizierung

## 🚀 Deployment

### Produktionsumgebung
1. **Environment Variables** konfigurieren
2. **MySQL Schema** importieren
3. **Docker Compose** für Produktion anpassen
4. **TLS/SSL** für API und LiveKit
5. **Firewall** für STUN/TURN Ports öffnen

### iOS App Store
1. **Apple Developer Account** konfigurieren
2. **Sign in with Apple** Capability aktivieren
3. **Location Services** Berechtigung hinzufügen
4. **Microphone** Berechtigung für Voice-Chat

## 🤝 Contributing

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/amazing-feature`)
3. Commits mit klaren Messages (`git commit -m 'Add amazing feature'`)
4. Branch pushen (`git push origin feature/amazing-feature`)
5. Pull Request erstellen

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

## 🆘 Support

Bei Fragen oder Problemen:
- **Issues**: GitHub Issues erstellen
- **Discussions**: GitHub Discussions nutzen
- **Email**: support@walkicar.app

---

**WalkiCar** - Verbinde dich mit Freunden, teile deine Fahrt und genieße Musik in voller Qualität! 🎵🚗