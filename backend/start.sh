#!/bin/bash

# WalkiCar Backend Start Script für Plesk
# Dieses Skript startet den WalkiCar Backend Server

cd /var/www/vhosts/timrmp.de/httpdocs/walkicar/backend

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

# Starte den Server
echo "🚀 Starte WalkiCar Backend Server..."
npm start
