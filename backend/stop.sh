#!/bin/bash

# WalkiCar Backend Stop Script für Plesk
# Dieses Skript stoppt den WalkiCar Backend Server (inkl. Socket.IO)

echo "🛑 Stoppe WalkiCar Backend Server (mit Socket.IO)..."

# Stoppe alle Node.js Prozesse die server.js ausführen
pkill -f "node server.js" || echo "Kein laufender Server gefunden"
pkill -f "walkicar-backend" || echo "Kein PM2-Prozess gefunden"

# Warte kurz
sleep 3

# Prüfe ob der Server gestoppt wurde
if pgrep -f "node server.js" > /dev/null; then
    echo "❌ Server läuft noch, forciere Stopp..."
    pkill -9 -f "node server.js"
    sleep 2
fi

# Prüfe Status
if pgrep -f "node server.js" > /dev/null; then
    echo "❌ Server konnte nicht gestoppt werden"
    exit 1
else
    echo "✅ WalkiCar Backend Server (mit Socket.IO) erfolgreich gestoppt"
fi
