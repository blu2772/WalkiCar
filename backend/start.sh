#!/bin/bash

# WalkiCar Backend Start Script für Plesk mit Coturn-Integration
# Dieses Skript startet Coturn und dann den WalkiCar Backend Server

cd /var/www/vhosts/timrmp.de/httpdocs/walkicar/backend

echo "🚀 === WalkiCar Full Stack Start ==="
echo "📅 $(date)"
echo ""

# Prüfe ob Node.js installiert ist
if ! command -v node &> /dev/null; then
    echo "❌ Node.js ist nicht installiert"
    exit 1
fi

# Prüfe ob npm installiert ist
if ! command -v npm &> /dev/null; then
    echo "❌ npm ist nicht installiert"
    exit 1
fi

# Prüfe ob .env Datei existiert
if [ ! -f .env ]; then
    echo "❌ .env Datei nicht gefunden"
    exit 1
fi

# Installiere Dependencies falls nötig
if [ ! -d node_modules ]; then
    echo "📦 Installiere Dependencies..."
    npm install
fi

# === COTURN MANAGEMENT ===
echo "📡 === Coturn-Server Management ==="

# Prüfe ob Coturn bereits läuft
if systemctl is-active --quiet coturn; then
    echo "✅ Coturn läuft bereits"
else
    echo "🚀 Starte Coturn-Server..."
    sudo systemctl start coturn
    
    # Warte kurz und prüfe Status
    sleep 3
    if systemctl is-active --quiet coturn; then
        echo "✅ Coturn erfolgreich gestartet"
    else
        echo "❌ Fehler beim Starten von Coturn"
        echo "🔍 Coturn Status:"
        sudo systemctl status coturn --no-pager -l
        echo ""
        echo "💡 Versuche trotzdem Backend zu starten..."
    fi
fi

# Zeige Coturn-Status
echo "📊 Coturn Status:"
sudo systemctl status coturn --no-pager -l | head -10
echo ""

# === BACKEND START ===
echo "🔧 === Backend-Server Start ==="

# Starte Backend
echo "🚀 Starte WalkiCar Backend Server..."
echo "💡 Verwende 'npm run start:full' für automatisches Coturn + Backend Management"
npm start
