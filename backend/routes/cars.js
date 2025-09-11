const express = require('express');
const Joi = require('joi');
const { query } = require('../config/database');

const router = express.Router();

// Validierungsschemas
const carSchema = Joi.object({
  name: Joi.string().min(1).max(100).required(),
  brand: Joi.string().max(50).optional(),
  model: Joi.string().max(50).optional(),
  year: Joi.number().integer().min(1900).max(new Date().getFullYear() + 1).optional(),
  color: Joi.string().max(30).optional(),
  bluetooth_identifier: Joi.string().max(100).optional(),
  audio_device_names: Joi.array().items(Joi.string().max(100)).optional()
});

const carUpdateSchema = Joi.object({
  name: Joi.string().min(1).max(100).optional(),
  brand: Joi.string().max(50).optional(),
  model: Joi.string().max(50).optional(),
  year: Joi.number().integer().min(1900).max(new Date().getFullYear() + 1).optional(),
  color: Joi.string().max(30).optional(),
  bluetooth_identifier: Joi.string().max(100).optional(),
  audio_device_names: Joi.array().items(Joi.string().max(100)).optional(),
  is_active: Joi.boolean().optional()
});

// Alle Fahrzeuge des Benutzers abrufen
router.get('/garage', async (req, res) => {
  try {
    const userId = req.user.id;

    const cars = await query(
      `SELECT id, name, brand, model, year, color, bluetooth_identifier, audio_device_names, is_active, created_at, updated_at
       FROM cars 
       WHERE user_id = ? 
       ORDER BY is_active DESC, created_at DESC`,
      [userId]
    );

    res.json({ cars });
  } catch (error) {
    console.error('Fahrzeug-Garage-Abruf-Fehler:', error);
    res.status(500).json({ 
      error: 'Fahrzeuge konnten nicht abgerufen werden',
      details: error.message
    });
  }
});

// Alle Fahrzeuge mit aktuellen Standorten abrufen (für Karte)
router.get('/with-locations', async (req, res) => {
  try {
    const userId = req.user.id;

    // Alle Autos des Benutzers mit ihren aktuellen Standorten
    const carsWithLocations = await query(`
      SELECT 
        c.id,
        c.name,
        c.brand,
        c.model,
        c.year,
        c.color,
        c.audio_device_names,
        c.is_active,
        c.created_at,
        c.updated_at,
        l.latitude,
        l.longitude,
        l.accuracy,
        l.speed,
        l.heading,
        l.altitude,
        l.timestamp as location_timestamp,
        CASE 
          WHEN l.timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN 'live'
          WHEN l.timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR) THEN 'parked'
          ELSE 'offline'
        END as status
      FROM cars c
      LEFT JOIN locations l ON c.id = l.car_id
      WHERE c.user_id = ?
      AND (l.id IS NULL OR l.id = (
        SELECT MAX(l2.id) 
        FROM locations l2 
        WHERE l2.car_id = c.id
      ))
      ORDER BY c.is_active DESC, l.timestamp DESC
    `, [userId]);

    res.json({ cars: carsWithLocations });
  } catch (error) {
    console.error('Fahrzeuge-mit-Standorten-Abruf-Fehler:', error);
    res.status(500).json({ 
      error: 'Fahrzeuge mit Standorten konnten nicht abgerufen werden',
      details: error.message
    });
  }
});

// Neues Fahrzeug erstellen
router.post('/create', async (req, res) => {
  try {
    const { error, value } = carSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { name, brand, model, year, color, bluetooth_identifier, audio_device_names } = value;
    const userId = req.user.id;

    // Überprüfe ob bereits ein Fahrzeug mit diesem Namen existiert
    const existingCar = await query(
      'SELECT id FROM cars WHERE user_id = ? AND name = ?',
      [userId, name]
    );

    if (existingCar.length > 0) {
      return res.status(409).json({ error: 'Ein Fahrzeug mit diesem Namen existiert bereits' });
    }

    // Erstelle neues Fahrzeug
    const result = await query(
      `INSERT INTO cars (user_id, name, brand, model, year, color, bluetooth_identifier, audio_device_names, is_active) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE)`,
      [userId, name, brand, model, year, color, bluetooth_identifier || null, JSON.stringify(audio_device_names)]
    );

    const carId = result.insertId;

    // Erstelle Standard-Standorteinstellungen für das Fahrzeug
    await query(
      `INSERT INTO location_settings (user_id, car_id, visibility, share_location) 
       VALUES (?, ?, 'private', FALSE)`,
      [userId, carId]
    );

    // Hole das erstellte Fahrzeug zurück
    const newCar = await query(
      'SELECT * FROM cars WHERE id = ?',
      [carId]
    );

    res.status(201).json({
      message: 'Fahrzeug erfolgreich erstellt',
      car: newCar[0]
    });

  } catch (error) {
    console.error('Fahrzeug-Erstellung-Fehler:', error);
    res.status(500).json({ 
      error: 'Fahrzeug konnte nicht erstellt werden',
      details: error.message
    });
  }
});

// Fahrzeug aktualisieren
router.put('/update/:car_id', async (req, res) => {
  try {
    const { car_id } = req.params;
    const { error, value } = carUpdateSchema.validate(req.body);
    
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const userId = req.user.id;

    // Überprüfe ob das Fahrzeug dem Benutzer gehört
    const car = await query(
      'SELECT id FROM cars WHERE id = ? AND user_id = ?',
      [car_id, userId]
    );

    if (car.length === 0) {
      return res.status(404).json({ error: 'Fahrzeug nicht gefunden' });
    }

    // Erstelle UPDATE-Query dynamisch
    const updateFields = [];
    const updateValues = [];
    
    Object.keys(value).forEach(key => {
      if (value[key] !== undefined) {
        if (key === 'audio_device_names') {
          // Spezielle Behandlung für JSON-Array
          updateFields.push(`${key} = ?`);
          updateValues.push(JSON.stringify(value[key]));
        } else {
          updateFields.push(`${key} = ?`);
          updateValues.push(value[key]);
        }
      }
    });

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'Keine Felder zum Aktualisieren angegeben' });
    }

    updateValues.push(car_id);
    
    await query(
      `UPDATE cars SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      updateValues
    );

    // Hole das aktualisierte Fahrzeug zurück
    const updatedCar = await query(
      'SELECT * FROM cars WHERE id = ?',
      [car_id]
    );

    res.json({
      message: 'Fahrzeug erfolgreich aktualisiert',
      car: updatedCar[0]
    });

  } catch (error) {
    console.error('Fahrzeug-Update-Fehler:', error);
    res.status(500).json({ 
      error: 'Fahrzeug konnte nicht aktualisiert werden',
      details: error.message
    });
  }
});

// Fahrzeug löschen
router.delete('/delete/:car_id', async (req, res) => {
  try {
    const { car_id } = req.params;
    const userId = req.user.id;

    // Überprüfe ob das Fahrzeug dem Benutzer gehört
    const car = await query(
      'SELECT id FROM cars WHERE id = ? AND user_id = ?',
      [car_id, userId]
    );

    if (car.length === 0) {
      return res.status(404).json({ error: 'Fahrzeug nicht gefunden' });
    }

    // Lösche das Fahrzeug (CASCADE löscht auch Standorteinstellungen)
    await query('DELETE FROM cars WHERE id = ?', [car_id]);

    res.json({ message: 'Fahrzeug erfolgreich gelöscht' });

  } catch (error) {
    console.error('Fahrzeug-Löschung-Fehler:', error);
    res.status(500).json({ 
      error: 'Fahrzeug konnte nicht gelöscht werden',
      details: error.message
    });
  }
});

// Aktives Fahrzeug setzen
router.put('/set-active/:car_id', async (req, res) => {
  try {
    const { car_id } = req.params;
    const userId = req.user.id;

    // Überprüfe ob das Fahrzeug dem Benutzer gehört
    const car = await query(
      'SELECT id FROM cars WHERE id = ? AND user_id = ?',
      [car_id, userId]
    );

    if (car.length === 0) {
      return res.status(404).json({ error: 'Fahrzeug nicht gefunden' });
    }

    // Setze alle Fahrzeuge des Benutzers auf inaktiv
    await query(
      'UPDATE cars SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?',
      [userId]
    );

    // Setze das gewählte Fahrzeug auf aktiv
    await query(
      'UPDATE cars SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [car_id]
    );

    res.json({ message: 'Aktives Fahrzeug erfolgreich gesetzt' });

  } catch (error) {
    console.error('Aktives-Fahrzeug-Setzen-Fehler:', error);
    res.status(500).json({ 
      error: 'Aktives Fahrzeug konnte nicht gesetzt werden',
      details: error.message
    });
  }
});

// Audio-Geräte für ein Fahrzeug setzen
router.put('/set-audio-devices/:car_id', async (req, res) => {
  try {
    const { car_id } = req.params;
    const { audio_device_names } = req.body;
    const userId = req.user.id;

    // Validierung
    if (!Array.isArray(audio_device_names)) {
      return res.status(400).json({ error: 'audio_device_names muss ein Array sein' });
    }

    // Überprüfe ob das Fahrzeug dem Benutzer gehört
    const car = await query(
      'SELECT id FROM cars WHERE id = ? AND user_id = ?',
      [car_id, userId]
    );

    if (car.length === 0) {
      return res.status(404).json({ error: 'Fahrzeug nicht gefunden' });
    }

    // Aktualisiere Audio-Geräte-Namen
    await query(
      'UPDATE cars SET audio_device_names = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [JSON.stringify(audio_device_names), car_id]
    );

    // Hole das aktualisierte Fahrzeug zurück
    const updatedCar = await query(
      'SELECT * FROM cars WHERE id = ?',
      [car_id]
    );

    res.json({
      message: 'Audio-Geräte erfolgreich gesetzt',
      car: updatedCar[0]
    });

  } catch (error) {
    console.error('Audio-Geräte-Setzen-Fehler:', error);
    res.status(500).json({ 
      error: 'Audio-Geräte konnten nicht gesetzt werden',
      details: error.message
    });
  }
});

module.exports = router;
