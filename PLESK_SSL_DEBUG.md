# Plesk SSL-Zertifikat-Pfade finden

## Problem
Der Node.js Server findet die Plesk SSL-Zertifikate nicht.

## Lösung: Korrekte Pfade finden

### Schritt 1: Plesk-Zertifikat-Pfade auf dem Server finden

Führe diese Befehle auf deinem Server (timrmp.de) aus:

```bash
# 1. Alle Zertifikat-Dateien finden
find /usr/local/psa/var/certificates/ -name "*timrmp*" -type f

# 2. Plesk-Zertifikat-Verzeichnis auflisten
ls -la /usr/local/psa/var/certificates/

# 3. Nach .crt und .key Dateien suchen
find /usr/local/psa/var/certificates/ -name "*.crt" | grep timrmp
find /usr/local/psa/var/certificates/ -name "*.key" | grep timrmp

# 4. Plesk-Konfiguration prüfen
cat /usr/local/psa/var/certificates/cert-*/timrmp.de.info 2>/dev/null || echo "Info-Datei nicht gefunden"
```

### Schritt 2: Umgebungsvariablen setzen

Wenn du die korrekten Pfade gefunden hast, setze sie als Umgebungsvariablen:

```bash
# In deiner .env Datei oder beim Server-Start:
export SSL_CERT_PATH="/usr/local/psa/var/certificates/cert-timrmp.de"
export SSL_KEY_PATH="/usr/local/psa/var/certificates/cert-timrmp.de.key"

# Oder direkt beim Server-Start:
SSL_CERT_PATH="/pfad/zum/zertifikat.crt" SSL_KEY_PATH="/pfad/zum/key.key" npm start
```

### Schritt 3: Alternative - Plesk Reverse Proxy verwenden

Da Plesk bereits HTTPS auf Port 443 bereitstellt, ist es besser, den Reverse Proxy zu verwenden:

1. **Plesk Control Panel** öffnen
2. **Domain "timrmp.de"** auswählen
3. **"Apache & nginx Settings"** öffnen
4. **"Additional nginx directives"** Tab

Füge hinzu:
```nginx
location /api/ {
    proxy_pass http://localhost:3000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Schritt 4: Node.js Server auf HTTP umstellen

Wenn du den Reverse Proxy verwendest, kann der Node.js Server auf HTTP laufen:

```javascript
// In server.js - HTTP verwenden, da Plesk HTTPS übernimmt
server = createServer(app);
```

### Schritt 5: iOS-App URL anpassen

Ändere die API-URL in der iOS-App zu:
```
https://timrmp.de/api
```

## Debug-Ausgaben interpretieren

Wenn du den Server startest, solltest du sehen:

```
🔍 Suche nach SSL-Zertifikaten...
📁 Prüfe Plesk-Zertifikat-Pfade:
   ❌ /usr/local/psa/var/certificates/cert-timrmp.de
   ❌ /usr/local/psa/var/certificates/scf-timrmp.de
📁 Prüfe Plesk-Key-Pfade:
   ❌ /usr/local/psa/var/certificates/cert-timrmp.de.key
   ❌ /usr/local/psa/var/certificates/scf-timrmp.de.key
```

Die ✅ oder ❌ zeigen dir, welche Pfade existieren.
