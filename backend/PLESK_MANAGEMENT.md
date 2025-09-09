# WalkiCar Backend - Plesk Management

## 🚀 Server Management

### NPM Skripte (empfohlen)
```bash
# Server starten
npm start

# Server stoppen
npm run stop

# Server neu starten
npm run restart

# Server Status prüfen
npm run status

# Logs anzeigen
npm run logs
```

### PM2 Skripte (falls PM2 installiert)
```bash
# PM2 Server starten
npm run pm2:start

# PM2 Server stoppen
npm run pm2:stop

# PM2 Server neu starten
npm run pm2:restart

# PM2 Status prüfen
npm run pm2:status

# PM2 Logs anzeigen
npm run pm2:logs
```

### Shell Skripte
```bash
# Server starten
./start.sh

# Server stoppen
./stop.sh

# Server neu starten
./restart.sh
```

## 📋 Plesk Konfiguration

### 1. Node.js Anwendung erstellen
- Gehe zu **Websites & Domains** → **Node.js**
- Klicke auf **Add Node.js App**
- **App Name**: `walkicar-backend`
- **App Root**: `/var/www/vhosts/timrmp.de/httpdocs/walkicar/backend`
- **App Startup File**: `server.js`
- **App URL**: `https://walkcar.timrmp.de`

### 2. Environment Variables setzen
- Gehe zu **Node.js** → **walkicar-backend** → **Environment Variables**
- Füge folgende Variablen hinzu:
  ```
  NODE_ENV=production
  PORT=3000
  DB_HOST=localhost
  DB_PORT=3306
  DB_NAME=walkicar_db
  DB_USER=walkicar_user
  DB_PASSWORD=walkicar123
  JWT_SECRET=walkicar_super_secret_jwt_key_2024_production
  JWT_EXPIRES_IN=7d
  ```

### 3. Reverse Proxy konfigurieren
- Gehe zu **Websites & Domains** → **walkcar.timrmp.de** → **Reverse Proxy**
- **Source URL**: `/api`
- **Destination URL**: `http://localhost:3000/api`

### 4. SSL Zertifikat
- Gehe zu **SSL/TLS Certificates**
- Stelle sicher, dass ein gültiges Zertifikat für `walkcar.timrmp.de` installiert ist

## 🔧 Troubleshooting

### Server startet nicht
1. Prüfe die Logs: `npm run logs`
2. Prüfe die .env Datei
3. Prüfe die Datenbankverbindung: `curl https://walkcar.timrmp.de/api/auth/test-db`

### Datenbankfehler
1. Prüfe ob MySQL läuft
2. Prüfe ob die Datenbank `walkicar_db` existiert
3. Prüfe ob der Benutzer `walkicar_user` existiert und Berechtigung hat

### API-Fehler
1. Prüfe die Reverse Proxy Konfiguration
2. Prüfe die CORS-Einstellungen
3. Prüfe die SSL-Zertifikate

## 📊 Monitoring

### Logs anzeigen
```bash
# NPM Logs
npm run logs

# PM2 Logs
npm run pm2:logs

# System Logs
tail -f /var/log/walkicar.log
```

### Status prüfen
```bash
# NPM Status
npm run status

# PM2 Status
npm run pm2:status

# Prozess prüfen
ps aux | grep "node server.js"
```

## 🔄 Deployment

### Automatisches Deployment
1. **Git Push** von lokal
2. **Git Pull** auf Server
3. **npm run restart** auf Server

### Manuelles Deployment
1. **Code hochladen** via FTP/SFTP
2. **Dependencies installieren**: `npm install`
3. **Server neu starten**: `npm run restart`
