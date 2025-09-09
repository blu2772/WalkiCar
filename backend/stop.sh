#!/bin/bash

# WalkiCar Backend Stop Script für Plesk
# Dieses Skript stoppt den WalkiCar Backend Server

echo "🛑 Stoppe WalkiCar Backend Server..."

# Stoppe alle Node.js Prozesse die server.js ausführen
pkill -f "node server.js" || echo "Kein laufender Server gefunden"

# Warte kurz
sleep 2

# Prüfe ob der Server gestoppt wurde
if pgrep -f "node server.js" > /dev/null; then
    echo "❌ Server läuft noch, forciere Stopp..."
    pkill -9 -f "node server.js"
    sleep 1
fi

# Prüfe Status
if pgrep -f "node server.js" > /dev/null; then
    echo "❌ Server konnte nicht gestoppt werden"
    exit 1
else
    echo "✅ Server erfolgreich gestoppt"
fi
