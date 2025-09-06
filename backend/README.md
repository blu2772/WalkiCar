# WalkiCar Backend

Das Backend für die WalkiCar App - eine Social- und Kommunikationsplattform für Autoliebhaber.

## 🚀 Features

- **Benutzerauthentifizierung** mit Apple Sign In
- **Freundesystem** mit Anfragen, Annahme/Ablehnung und Blockierung
- **JWT-basierte Authentifizierung**
- **MySQL Datenbank** mit optimierten Indizes
- **Socket.IO** für Echtzeit-Kommunikation
- **RESTful API** mit Express.js
- **Sicherheitsmiddleware** (Helmet, CORS, Rate Limiting)

## 📋 Voraussetzungen

- Node.js >= 18.0.0
- MySQL >= 8.0
- npm oder yarn

## 🛠️ Installation

1. **Abhängigkeiten installieren:**
   ```bash
   npm install
   ```

2. **Umgebungsvariablen konfigurieren:**
   ```bash
   cp env.example .env
   ```
   
   Bearbeite die `.env` Datei mit deinen Datenbank- und API-Schlüsseln.

3. **Datenbank einrichten:**
   ```bash
   # MySQL-Datenbank erstellen
   mysql -u root -p
   CREATE DATABASE walkicar_db;
   CREATE USER 'walkicar_user'@'localhost' IDENTIFIED BY 'your_secure_password';
   GRANT ALL PRIVILEGES ON walkicar_db.* TO 'walkicar_user'@'localhost';
   FLUSH PRIVILEGES;
   ```

4. **Datenbank-Schema importieren:**
   ```bash
   mysql -u walkicar_user -p walkicar_db < ../db/walkicar_schema.sql
   ```

## 🚀 Starten

**Entwicklung:**
```bash
npm run dev
```

**Produktion:**
```bash
npm start
```

Der Server läuft standardmäßig auf Port 3000.

## 📚 API Endpunkte

### Authentifizierung (`/api/auth`)

- `POST /register` - Benutzerregistrierung mit Apple Sign In
- `POST /login` - Benutzeranmeldung
- `POST /logout` - Benutzerabmeldung
- `POST /refresh` - Token erneuern
- `GET /profile` - Benutzerprofil abrufen

### Freunde (`/api/friends`)

- `POST /request` - Freundschaftsanfrage senden
- `GET /requests` - Ausstehende Freundschaftsanfragen abrufen
- `PUT /action` - Freundschaftsanfrage bearbeiten (annehmen/ablehnen/blockieren)
- `GET /list` - Freundesliste abrufen
- `DELETE /remove/:id` - Freund entfernen
- `GET /blocked` - Blockierte Freunde abrufen
- `PUT /unblock/:id` - Freund entsperren
- `GET /search` - Benutzer suchen

### Fahrzeuge (`/api/cars`)
*Wird implementiert*

### Gruppen (`/api/groups`)
*Wird implementiert*

### Standorte (`/api/locations`)
*Wird implementiert*

## 🔧 Konfiguration

### Umgebungsvariablen

```env
# Server
PORT=3000
NODE_ENV=development

# Datenbank
DB_HOST=localhost
DB_PORT=3306
DB_NAME=walkicar_db
DB_USER=walkicar_user
DB_PASSWORD=your_secure_password

# JWT
JWT_SECRET=your_super_secret_jwt_key
JWT_EXPIRES_IN=7d

# Apple Sign In
APPLE_CLIENT_ID=your_apple_client_id
APPLE_TEAM_ID=your_apple_team_id
APPLE_KEY_ID=your_apple_key_id
APPLE_PRIVATE_KEY_PATH=./keys/AuthKey_XXXXXXXXXX.p8
```

## 🗄️ Datenbank-Schema

Die Datenbank enthält folgende Haupttabellen:

- `users` - Benutzerinformationen
- `friendships` - Freundschaftsbeziehungen
- `cars` - Fahrzeugdaten
- `groups` - Gruppen für Voice-Chats
- `locations` - Standortdaten
- `notifications` - Benachrichtigungen
- `user_sessions` - JWT-Session-Management

## 🔒 Sicherheit

- **JWT-Token** für Authentifizierung
- **bcrypt** für Passwort-Hashing
- **Helmet** für HTTP-Sicherheitsheader
- **CORS** für Cross-Origin-Requests
- **Rate Limiting** gegen Missbrauch
- **Input-Validierung** mit Joi

## 🧪 Testing

```bash
npm test
```

## 📝 Logs

Das Backend loggt wichtige Ereignisse und Fehler in die Konsole. In der Produktion sollten Logs in Dateien oder einem Logging-Service gespeichert werden.

## 🚀 Deployment

1. **Produktionsumgebung vorbereiten:**
   - `NODE_ENV=production` setzen
   - Sichere JWT-Secrets verwenden
   - Datenbankzugriff einschränken

2. **PM2 für Prozess-Management:**
   ```bash
   npm install -g pm2
   pm2 start server.js --name walkicar-backend
   ```

3. **Nginx als Reverse Proxy:**
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

## 🤝 Beitragen

1. Fork das Repository
2. Erstelle einen Feature-Branch
3. Committe deine Änderungen
4. Push zum Branch
5. Erstelle einen Pull Request

## 📄 Lizenz

MIT License - siehe LICENSE Datei für Details.
