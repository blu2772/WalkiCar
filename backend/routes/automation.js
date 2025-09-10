const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const db = require('../config/database');

// POST /automation/bluetooth-event
// Verarbeitet Bluetooth-Verbindungs-/Trennungs-Events von Apple Automatisierung
router.post('/bluetooth-event', authenticateToken, async (req, res) => {
    try {
        const { action, carId, deviceId, timestamp } = req.body;
        
        console.log(`🔗 Automation: Bluetooth Event - Action: ${action}, CarID: ${carId}, DeviceID: ${deviceId}`);
        
        // Validierung
        if (!action || !carId) {
            return res.status(400).json({
                error: 'Fehlende Parameter',
                details: 'action und carId sind erforderlich'
            });
        }
        
        if (!['connected', 'disconnected'].includes(action)) {
            return res.status(400).json({
                error: 'Ungültige Aktion',
                details: 'action muss "connected" oder "disconnected" sein'
            });
        }
        
        // Prüfe ob das Auto dem Benutzer gehört
        const [carRows] = await db.execute(
            'SELECT id, name FROM cars WHERE id = ? AND user_id = ?',
            [carId, req.user.userId]
        );
        
        if (carRows.length === 0) {
            return res.status(404).json({
                error: 'Auto nicht gefunden',
                details: 'Das Auto gehört nicht zu diesem Benutzer'
            });
        }
        
        const car = carRows[0];
        
        if (action === 'connected') {
            // Auto als aktiv setzen
            await db.execute(
                'UPDATE cars SET is_active = 1, bluetooth_device_id = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                [deviceId || null, carId]
            );
            
            console.log(`✅ Automation: Auto "${car.name}" (ID: ${carId}) als aktiv gesetzt`);
            
            res.json({
                message: 'Auto erfolgreich aktiviert',
                car: {
                    id: carId,
                    name: car.name,
                    isActive: true,
                    bluetoothDeviceId: deviceId
                }
            });
            
        } else if (action === 'disconnected') {
            // Auto als inaktiv setzen und Standort-Tracking stoppen
            await db.execute(
                'UPDATE cars SET is_active = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                [carId]
            );
            
            // Aktuellen Standort als geparkt markieren
            const [locationRows] = await db.execute(
                'SELECT id FROM locations WHERE car_id = ? AND is_live = 1 ORDER BY created_at DESC LIMIT 1',
                [carId]
            );
            
            if (locationRows.length > 0) {
                const locationId = locationRows[0].id;
                
                // Standort als geparkt markieren
                await db.execute(
                    'UPDATE locations SET is_live = 0, parked_at = CURRENT_TIMESTAMP WHERE id = ?',
                    [locationId]
                );
                
                // In parked_locations Tabelle speichern
                await db.execute(
                    'INSERT INTO parked_locations (car_id, latitude, longitude, parked_at, created_at) ' +
                    'SELECT car_id, latitude, longitude, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP ' +
                    'FROM locations WHERE id = ?',
                    [locationId]
                );
                
                console.log(`🅿️ Automation: Auto "${car.name}" (ID: ${carId}) als geparkt markiert`);
            }
            
            res.json({
                message: 'Auto erfolgreich deaktiviert und geparkt',
                car: {
                    id: carId,
                    name: car.name,
                    isActive: false
                }
            });
        }
        
    } catch (error) {
        console.error('❌ Automation Error:', error);
        res.status(500).json({
            error: 'Automatisierung-Event konnte nicht verarbeitet werden',
            details: error.message
        });
    }
});

// GET /automation/car/:carId/template
// Gibt URL-Template für Automatisierung zurück
router.get('/car/:carId/template', authenticateToken, async (req, res) => {
    try {
        const carId = req.params.carId;
        
        // Prüfe ob das Auto dem Benutzer gehört
        const [carRows] = await db.execute(
            'SELECT id, name FROM cars WHERE id = ? AND user_id = ?',
            [carId, req.user.userId]
        );
        
        if (carRows.length === 0) {
            return res.status(404).json({
                error: 'Auto nicht gefunden',
                details: 'Das Auto gehört nicht zu diesem Benutzer'
            });
        }
        
        const car = carRows[0];
        
        res.json({
            car: {
                id: car.id,
                name: car.name
            },
            templates: {
                connected: `walkicar://bluetooth/connected?carId=${carId}`,
                disconnected: `walkicar://bluetooth/disconnected?carId=${carId}`
            },
            instructions: {
                title: 'Automatisierung einrichten',
                steps: [
                    'Shortcuts-App öffnen',
                    'Automatisierung erstellen',
                    'Bluetooth-Trigger wählen',
                    'URL-Aktion hinzufügen',
                    'Automatisierung aktivieren'
                ]
            }
        });
        
    } catch (error) {
        console.error('❌ Template Error:', error);
        res.status(500).json({
            error: 'Template konnte nicht erstellt werden',
            details: error.message
        });
    }
});

module.exports = router;
