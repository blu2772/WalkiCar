# HTTPS für WalkiCar API aktivieren

## Schritt 1: SSL-Zertifikat mit Let's Encrypt erstellen

### Auf deinem Server (timrmp.de) ausführen:

```bash
# 1. Certbot installieren
sudo apt update
sudo apt install certbot

# 2. SSL-Zertifikat für timrmp.de erstellen
sudo certbot certonly --standalone -d timrmp.de

# 3. Zertifikat-Pfade überprüfen
ls -la /etc/letsencrypt/live/timrmp.de/
```

## Schritt 2: Node.js Server neu starten

```bash
# 1. Zum Backend-Verzeichnis wechseln
cd /path/to/walkicar/backend

# 2. Server neu starten
npm start
```

Der Server sollte jetzt automatisch HTTPS verwenden, wenn die SSL-Zertifikate gefunden werden.

## Schritt 3: iOS-App testen

Die iOS-App ist bereits auf HTTPS konfiguriert. Teste die Registrierung:

1. Xcode öffnen
2. App starten
3. Registrierungsformular ausfüllen
4. "Registrieren" klicken

## Schritt 4: Automatische Zertifikat-Erneuerung

```bash
# Cron-Job für automatische Erneuerung einrichten
sudo crontab -e

# Diese Zeile hinzufügen (täglich um 2 Uhr morgens prüfen):
0 2 * * * /usr/bin/certbot renew --quiet && systemctl reload nginx
```

## Troubleshooting

### SSL-Zertifikat nicht gefunden:
- Prüfe ob die Pfade korrekt sind: `/etc/letsencrypt/live/timrmp.de/`
- Stelle sicher, dass Port 80 und 443 offen sind
- Prüfe die Firewall-Einstellungen

### Server startet nicht:
- Prüfe die SSL-Zertifikat-Berechtigungen
- Stelle sicher, dass Node.js die Zertifikate lesen kann

### iOS-App kann nicht verbinden:
- Prüfe ob der Server auf HTTPS läuft
- Teste die Verbindung mit: `curl -I https://timrmp.de:3000/api/auth/register-email`
