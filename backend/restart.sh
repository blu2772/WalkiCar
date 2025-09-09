#!/bin/bash

# WalkiCar Backend Restart Script für Plesk
# Dieses Skript startet den WalkiCar Backend Server neu

echo "🔄 Starte WalkiCar Backend Server neu..."

# Stoppe den Server
./stop.sh

# Warte kurz
sleep 3

# Starte den Server neu
./start.sh
