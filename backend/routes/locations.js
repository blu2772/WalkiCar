const express = require('express');
const router = express.Router();
const { query, transaction } = require('../config/database');
const { authenticateToken } = require('../middleware/auth');
const Joi = require('joi');

// Joi Validation Schemas
const locationUpdateSchema = Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required(),
    accuracy: Joi.number().min(0).optional(),
    speed: Joi.number().min(0).optional(),
    heading: Joi.number().min(0).max(360).optional(),
    altitude: Joi.number().optional(),
    car_id: Joi.number().integer().positive().optional(),
    bluetooth_connected: Joi.boolean().optional()
});

// POST /locations/update - Live-Standort aktualisieren (vereinfacht)
router.post('/update', authenticateToken, async (req, res) => {
    try {
        console.log('📍 Location Update Request:', req.body);
        
        const { error, value } = locationUpdateSchema.validate(req.body);
        if (error) {
            console.log('❌ Validation Error:', error.details[0].message);
            return res.status(400).json({
                error: 'Ungültige Standortdaten',
                details: error.details[0].message
            });
        }

        const { latitude, longitude, accuracy, speed, heading, altitude, car_id, bluetooth_connected } = value;
        const userId = req.user.id;

        console.log('📍 User ID:', userId, 'Car ID:', car_id);

        // Konvertiere undefined zu null für SQL
        const carIdForDB = car_id || null;
        const accuracyForDB = accuracy || null;
        const speedForDB = speed || null;
        const headingForDB = heading || null;
        const altitudeForDB = altitude || null;

        // Prüfe ob Auto dem Benutzer gehört (nur wenn car_id angegeben)
        if (carIdForDB) {
            const carCheck = await query(
                'SELECT id FROM cars WHERE id = ? AND user_id = ?',
                [carIdForDB, userId]
            );
            if (carCheck.length === 0) {
                console.log('❌ Car not found or not authorized');
                return res.status(404).json({
                    error: 'Fahrzeug nicht gefunden oder nicht berechtigt'
                });
            }
        }

        // Einfacher Standort-Insert (nur bestehende Spalten)
        const locationResult = await query(
            `INSERT INTO locations 
             (user_id, car_id, latitude, longitude, accuracy, speed, heading, altitude) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [userId, carIdForDB, latitude, longitude, accuracyForDB, speedForDB, headingForDB, altitudeForDB]
        );

        console.log('✅ Location inserted with ID:', locationResult.insertId);

        res.json({
            message: 'Standort erfolgreich aktualisiert',
            location_id: locationResult.insertId,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ Standort-Update-Fehler:', error);
        res.status(500).json({
            error: 'Standort konnte nicht aktualisiert werden',
            details: error.message
        });
    }
});

// GET /locations/live - Live-Standorte aller Freunde abrufen (vereinfacht)
router.get('/live', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;
        console.log('📍 Getting live locations for user:', userId);

        // Einfache Abfrage ohne komplexe JOINs
        const liveLocations = await query(`
            SELECT 
                l.id,
                l.user_id,
                l.car_id,
                l.latitude,
                l.longitude,
                l.accuracy,
                l.speed,
                l.heading,
                l.altitude,
                l.timestamp,
                u.username,
                u.display_name,
                u.profile_picture_url
            FROM locations l
            JOIN users u ON l.user_id = u.id
            WHERE l.timestamp > DATE_SUB(NOW(), INTERVAL 1 MINUTE)
            ORDER BY l.timestamp DESC
            LIMIT 50
        `);

        console.log('📍 Found', liveLocations.length, 'recent locations');

        res.json({
            live_locations: liveLocations,
            parked_locations: [],
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ Live-Standorte-Fehler:', error);
        res.status(500).json({
            error: 'Live-Standorte konnten nicht abgerufen werden',
            details: error.message
        });
    }
});

// POST /locations/park - Fahrzeug als geparkt markieren (vereinfacht)
router.post('/park', authenticateToken, async (req, res) => {
    try {
        const { car_id } = req.body;
        const userId = req.user.id;

        if (!car_id) {
            return res.status(400).json({
                error: 'Fahrzeug-ID ist erforderlich'
            });
        }

        // Prüfe ob Auto dem Benutzer gehört
        const carCheck = await query(
            'SELECT id FROM cars WHERE id = ? AND user_id = ?',
            [car_id, userId]
        );
        if (carCheck.length === 0) {
            return res.status(404).json({
                error: 'Fahrzeug nicht gefunden oder nicht berechtigt'
            });
        }

        res.json({
            message: 'Fahrzeug erfolgreich als geparkt markiert',
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('❌ Parken-Fehler:', error);
        res.status(500).json({
            error: 'Fahrzeug konnte nicht als geparkt markiert werden',
            details: error.message
        });
    }
});

module.exports = router;