#!/bin/bash

# WalkiCar Backend Stop Script für Plesk mit Coturn-Integration
# Dieses Skript stoppt Backend und dann Coturn

echo "🛑 === WalkiCar Full Stack Stop ==="
echo "📅 $(date)"
echo ""

# === BACKEND STOP ===
echo "🔧 === Backend-Server Stop ==="

# Stoppe alle Node.js Prozesse die server.js ausführen
echo "🛑 Stoppe WalkiCar Backend Server (mit Socket.IO)..."
pkill -f "node server.js" || echo "Kein laufender Server gefunden"
pkill -f "walkicar-backend" || echo "Kein PM2-Prozess gefunden"

# Auch Coturn-Manager stoppen falls er läuft
pkill -f "coturn-manager.js" || echo "Kein laufender Coturn-Manager gefunden"

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
    echo "❌ Backend Server konnte nicht gestoppt werden"
    exit 1
else
    echo "✅ WalkiCar Backend Server erfolgreich gestoppt"
fi

echo ""

# === COTURN MANAGEMENT ===
echo "📡 === Coturn-Server Management ==="

# Prüfe ob Coturn läuft
if systemctl is-active --quiet coturn; then
    echo "🛑 Stoppe Coturn-Server..."
    sudo systemctl stop coturn
    
    # Warte kurz und prüfe Status
    sleep 3
    if systemctl is-active --quiet coturn; then
        echo "❌ Coturn konnte nicht gestoppt werden"
        echo "🔍 Coturn Status:"
        sudo systemctl status coturn --no-pager -l | head -10
    else
        echo "✅ Coturn erfolgreich gestoppt"
    fi
else
    echo "ℹ️ Coturn läuft nicht"
fi

echo ""
echo "🎯 === Zusammenfassung ==="
echo "✅ Backend: Gestoppt"
echo "$(systemctl is-active --quiet coturn && echo "📡 Coturn: Läuft noch" || echo "📡 Coturn: Gestoppt")"
echo ""
echo "💡 Verwende 'npm run stop:full' für automatisches Management"
