# Subdomain walkcar.timrmp.de für WalkiCar API

## ✅ iOS-App ist bereits konfiguriert!

Die iOS-App verwendet bereits: `https://walkcar.timrmp.de/api`

## 🔧 Plesk Subdomain konfigurieren

### Schritt 1: Subdomain in Plesk erstellen

1. **Plesk Control Panel** öffnen
2. **Domain "timrmp.de"** auswählen
3. **"Subdomains"** klicken
4. **"Add Subdomain"** klicken

### Schritt 2: Subdomain-Details eingeben

- **Subdomain name:** `walkcar`
- **Document root:** `/var/www/vhosts/timrmp.de/walkcar.timrmp.de`
- **DNS zone:** `timrmp.de` (automatisch ausgewählt)

### Schritt 3: SSL-Zertifikat für Subdomain

1. **Subdomain "walkcar.timrmp.de"** auswählen
2. **"SSL/TLS Certificates"** öffnen
3. **"Let's Encrypt"** klicken
4. **"Get a free certificate from Let's Encrypt"** auswählen
5. **"Get it free"** klicken

### Schritt 4: nginx Reverse Proxy konfigurieren

1. **Subdomain "walkcar.timrmp.de"** auswählen
2. **"Apache & nginx Settings"** öffnen
3. **"Additional nginx directives"** Tab

Füge diese Konfiguration hinzu:

```nginx
# WalkiCar API Reverse Proxy
location /api/ {
    proxy_pass http://localhost:3000/api/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;
}

# Optional: Alle anderen Anfragen auf eine Info-Seite weiterleiten
location / {
    return 200 'WalkiCar API Server - Use /api/ endpoints';
    add_header Content-Type text/plain;
}
```

### Schritt 5: Node.js Server starten

```bash
# Auf deinem Server:
cd /path/to/walkicar/backend
npm start
```

Du solltest sehen:
```
🔄 Plesk Reverse Proxy Modus - HTTP verwendet
🚗 WalkiCar Backend läuft auf http://localhost:3000
```

### Schritt 6: iOS-App testen

- **Xcode öffnen** und App starten
- **Registrierung testen**

## 🔍 Testen der Konfiguration

### Server-seitig testen:
```bash
# Teste den lokalen Server:
curl http://localhost:3000/api/auth/register-email

# Teste über Subdomain (sollte HTTPS verwenden):
curl https://walkcar.timrmp.de/api/auth/register-email
```

### iOS-App Debug-Ausgaben:
Du solltest sehen:
```
🌐 API-Aufruf: POST https://walkcar.timrmp.de/api/auth/register-email
📡 HTTP-Request wird gesendet...
📊 HTTP-Status: 201
✅ Response erfolgreich dekodiert
```

## ✅ Vorteile der Subdomain-Lösung

- ✅ **Saubere URL:** `https://walkcar.timrmp.de/api`
- ✅ **Keine Port-Nummer** in der URL
- ✅ **Eigene SSL-Zertifikat** für die Subdomain
- ✅ **Professioneller** als Hauptdomain + /api
- ✅ **Einfacher zu verwalten** in Plesk
- ✅ **Bessere Trennung** zwischen Website und API
- ✅ **Skalierbar** für weitere Services

## 🚨 Troubleshooting

### Wenn die Subdomain nicht funktioniert:

1. **DNS prüfen:**
   ```bash
   nslookup walkcar.timrmp.de
   ```

2. **SSL-Zertifikat prüfen:**
   - Ist das Let's Encrypt Zertifikat aktiv?
   - Läuft es ohne Fehler?

3. **nginx-Konfiguration prüfen:**
   - Sind die directives korrekt eingefügt?
   - Wurde die Konfiguration gespeichert?

4. **Node.js Server prüfen:**
   - Läuft der Server auf Port 3000?
   - Siehst du "Plesk Reverse Proxy Modus"?

### Alternative: Hauptdomain verwenden

Falls die Subdomain Probleme macht, kannst du auch die Hauptdomain verwenden:

1. **iOS-App URL ändern zu:** `https://timrmp.de/api`
2. **nginx-Konfiguration** in der Hauptdomain hinzufügen
3. **CORS im Backend** auf `timrmp.de` ändern
