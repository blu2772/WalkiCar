#!/bin/bash

# WalkiCar Backend Restart Script für Plesk
# Dieses Skript startet den WalkiCar Backend Server neu (inkl. Socket.IO)

echo "🔄 Starte WalkiCar Backend Server neu (mit Socket.IO)..."

# Stoppe alle WalkiCar-Prozesse
echo "🛑 Stoppe alle WalkiCar-Prozesse..."
pkill -f "node server.js" || echo "Kein laufender Server gefunden"
pkill -f "walkicar-backend" || echo "Kein PM2-Prozess gefunden"

# Warte bis alle Prozesse gestoppt sind
sleep 5

# Prüfe ob noch Prozesse laufen
if pgrep -f "node server.js" > /dev/null; then
    echo "⚠️ Forciere Stopp der verbleibenden Prozesse..."
    pkill -9 -f "node server.js"
    sleep 2
fi

# Starte den Server neu
echo "🚀 Starte WalkiCar Backend Server (mit Socket.IO)..."
cd /var/www/vhosts/timrmp.de/httpdocs/walkicar/backend
npm start &

# Warte kurz und prüfe Status
sleep 3
if pgrep -f "node server.js" > /dev/null; then
    echo "✅ WalkiCar Backend Server (mit Socket.IO) erfolgreich gestartet"
else
    echo "❌ Fehler beim Starten des Servers"
    exit 1
fi
