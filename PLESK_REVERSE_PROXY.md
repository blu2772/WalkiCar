# Plesk Reverse Proxy für WalkiCar API

## Problem
- Plesk SSL-Zertifikat ist für Port 443 konfiguriert
- Node.js Server läuft auf Port 3000
- Direkte HTTPS-Verbindung zu Port 3000 funktioniert nicht

## Lösung: Plesk Reverse Proxy

### Schritt 1: Plesk Reverse Proxy konfigurieren

1. **Plesk Control Panel** öffnen
2. **Domain "timrmp.de"** auswählen
3. **"Apache & nginx Settings"** öffnen
4. **"Additional nginx directives"** Tab

### Schritt 2: nginx Reverse Proxy Konfiguration

Füge diese Konfiguration hinzu:

```nginx
# Reverse Proxy für WalkiCar API
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

### Schritt 3: iOS-App URL anpassen

Ändere die API-URL in der iOS-App von:
```
https://timrmp.de:3000/api
```

zu:
```
https://timrmp.de/api
```

### Schritt 4: Node.js Server auf HTTP umstellen

Da Plesk den HTTPS-Teil übernimmt, kann der Node.js Server auf HTTP laufen:

```javascript
// In server.js - HTTP verwenden, da Plesk HTTPS übernimmt
server = createServer(app);
```

### Schritt 5: CORS konfigurieren

Stelle sicher, dass CORS für die neue Domain konfiguriert ist:

```javascript
app.use(cors({
  origin: ['https://timrmp.de', 'http://localhost:3000'],
  credentials: true
}));
```

## Vorteile dieser Lösung

✅ **Plesk SSL-Zertifikat** wird verwendet
✅ **Standard HTTPS-Port 443** 
✅ **Keine Port-Probleme** mehr
✅ **Professionelle URL** ohne Port-Nummer
✅ **Plesk-Management** für SSL-Zertifikate
