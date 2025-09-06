# Plesk Reverse Proxy für WalkiCar API - Schritt-für-Schritt

## ✅ Node.js Server ist bereits konfiguriert!

Der Node.js Server läuft jetzt auf HTTP (Port 3000) und ist bereit für den Plesk Reverse Proxy.

## 🔧 Plesk Reverse Proxy konfigurieren

### Schritt 1: Plesk Control Panel öffnen
1. **Plesk Control Panel** in deinem Browser öffnen
2. **Domain "timrmp.de"** auswählen
3. **"Apache & nginx Settings"** klicken

### Schritt 2: nginx Directives hinzufügen
1. **"Additional nginx directives"** Tab öffnen
2. **Diese Konfiguration hinzufügen:**

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
```

### Schritt 3: Konfiguration speichern
1. **"OK"** oder **"Apply"** klicken
2. **Warten** bis Plesk die Konfiguration anwendet

### Schritt 4: Node.js Server starten
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

### Schritt 5: iOS-App testen
- **Xcode öffnen** und App starten
- **Registrierung testen** - sollte jetzt funktionieren!

## 🔍 Testen der Konfiguration

### Server-seitig testen:
```bash
# Teste den lokalen Server:
curl http://localhost:3000/api/auth/register-email

# Teste über Plesk (sollte HTTPS verwenden):
curl https://timrmp.de/api/auth/register-email
```

### iOS-App Debug-Ausgaben:
Du solltest sehen:
```
🌐 API-Aufruf: POST https://timrmp.de/api/auth/register-email
📡 HTTP-Request wird gesendet...
📊 HTTP-Status: 201
✅ Response erfolgreich dekodiert
```

## ✅ Vorteile dieser Lösung

- ✅ **Plesk SSL-Zertifikat** wird verwendet
- ✅ **Standard HTTPS-Port 443** (keine Port-Nummer)
- ✅ **Professionelle URL** `https://timrmp.de/api`
- ✅ **Keine iOS App Transport Security** Probleme
- ✅ **Plesk verwaltet SSL** automatisch
- ✅ **Node.js Server** läuft einfach auf HTTP

## 🚨 Troubleshooting

### Wenn es nicht funktioniert:

1. **Plesk-Konfiguration prüfen:**
   - Sind die nginx directives korrekt eingefügt?
   - Wurde die Konfiguration gespeichert?

2. **Node.js Server prüfen:**
   - Läuft der Server auf Port 3000?
   - Siehst du die Meldung "Plesk Reverse Proxy Modus"?

3. **Firewall prüfen:**
   - Ist Port 3000 lokal erreichbar?
   - Kann Plesk auf localhost:3000 zugreifen?

4. **Logs prüfen:**
   - Plesk Error Logs
   - Node.js Server Console
   - iOS-App Debug-Ausgaben
