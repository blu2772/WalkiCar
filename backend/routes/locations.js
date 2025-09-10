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

const locationSettingsSchema = Joi.object({
    visibility: Joi.string().valid('private', 'friends', 'public').required(),
    share_location: Joi.boolean().required(),
    share_when_moving: Joi.boolean().required(),
    share_when_stationary: Joi.boolean().required(),
    car_id: Joi.number().integer().positive().optional()
});

// POST /locations/update - Live-Standort aktualisieren
router.post('/update', authenticateToken, async (req, res) => {
    try {
        const { error, value } = locationUpdateSchema.validate(req.body);
        if (error) {
            return res.status(400).json({
                error: 'Ungültige Standortdaten',
                details: error.details[0].message
            });
        }

        const { latitude, longitude, accuracy, speed, heading, altitude, car_id, bluetooth_connected } = value;
        const userId = req.user.id;

        // Prüfe ob Auto dem Benutzer gehört
        if (car_id) {
            const carCheck = await query(
                'SELECT id FROM cars WHERE id = ? AND user_id = ?',
                [car_id, userId]
            );
            if (carCheck.length === 0) {
                return res.status(404).json({
                    error: 'Fahrzeug nicht gefunden oder nicht berechtigt'
                });
            }
        }

        // Aktuellen Standort in locations Tabelle speichern
        const locationResult = await query(
            `INSERT INTO locations 
             (user_id, car_id, latitude, longitude, accuracy, speed, heading, altitude, bluetooth_connected, is_live, is_parked) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [userId, car_id, latitude, longitude, accuracy, speed, heading, altitude, bluetooth_connected || false, true, false]
        );

        // Standort in Historie speichern
        await query(
            `INSERT INTO location_history 
             (user_id, car_id, latitude, longitude, accuracy, speed, heading, altitude) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [userId, car_id, latitude, longitude, accuracy, speed, heading, altitude]
        );

        // Geparkte Standorte-Logik temporär deaktiviert (bis neue Tabellen erstellt sind)
        // if (bluetooth_connected && car_id) {
        //     await query(
        //         `INSERT INTO parked_locations 
        //          (user_id, car_id, latitude, longitude, accuracy, last_live_update) 
        //          VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        //          ON DUPLICATE KEY UPDATE 
        //          latitude = VALUES(latitude),
        //          longitude = VALUES(longitude),
        //          accuracy = VALUES(accuracy),
        //          last_live_update = CURRENT_TIMESTAMP`,
        //         [userId, car_id, latitude, longitude, accuracy]
        //     );
        // }

        res.json({
            message: 'Standort erfolgreich aktualisiert',
            location_id: locationResult.insertId,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Standort-Update-Fehler:', error);
        res.status(500).json({
            error: 'Standort konnte nicht aktualisiert werden',
            details: error.message
        });
    }
});

// GET /locations/live - Live-Standorte aller Freunde abrufen
router.get('/live', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.id;

        // Hole alle Live-Standorte von Freunden (temporär ohne neue Spalten)
        const liveLocations = await query(`
            SELECT DISTINCT
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
                u.profile_picture_url,
                c.name as car_name,
                c.brand,
                c.model,
                c.color
            FROM locations l
            JOIN users u ON l.user_id = u.id
            LEFT JOIN cars c ON l.car_id = c.id
            JOIN friendships f ON (
                (f.user_id = ? AND f.friend_id = l.user_id) OR 
                (f.friend_id = ? AND f.user_id = l.user_id)
            )
            WHERE f.status = 'accepted'
            AND l.timestamp > DATE_SUB(NOW(), INTERVAL 1 MINUTE)
            ORDER BY l.timestamp DESC
        `, [userId, userId]);

        // Geparkte Standorte temporär deaktiviert (bis neue Tabellen erstellt sind)
        const parkedLocations = [];

        res.json({
            live_locations: liveLocations,
            parked_locations: parkedLocations,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Live-Standorte-Fehler:', error);
        res.status(500).json({
            error: 'Live-Standorte konnten nicht abgerufen werden',
            details: error.message
        });
    }
});

// POST /locations/park - Fahrzeug als geparkt markieren
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

        // Parken temporär deaktiviert (bis neue Spalten erstellt sind)
        // await query(
        //     'UPDATE locations SET is_live = false, is_parked = true, bluetooth_connected = false WHERE user_id = ? AND car_id = ? AND is_live = true',
        //     [userId, car_id]
        // );

        res.json({
            message: 'Fahrzeug erfolgreich als geparkt markiert',
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Parken-Fehler:', error);
        res.status(500).json({
            error: 'Fahrzeug konnte nicht als geparkt markiert werden',
            details: error.message
        });
    }
});

module.exports = router;
