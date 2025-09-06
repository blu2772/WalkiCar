const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const Joi = require('joi');
const { query, transaction } = require('../config/database');
const { generateToken } = require('../middleware/auth');

const router = express.Router();

// Validierungsschemas
const registerSchema = Joi.object({
  apple_id: Joi.string().required(),
  email: Joi.string().email().required(),
  username: Joi.string().alphanum().min(3).max(30).required(),
  display_name: Joi.string().min(1).max(100).required()
});

const loginSchema = Joi.object({
  apple_id: Joi.string().required(),
  email: Joi.string().email().required()
});

// Apple Sign In Registrierung
router.post('/register', async (req, res) => {
  try {
    const { error, value } = registerSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { apple_id, email, username, display_name } = value;

    // Überprüfe ob Benutzer bereits existiert
    const existingUser = await query(
      'SELECT id FROM users WHERE apple_id = ? OR email = ? OR username = ?',
      [apple_id, email, username]
    );

    if (existingUser.length > 0) {
      return res.status(409).json({ error: 'Benutzer existiert bereits' });
    }

    // Erstelle neuen Benutzer
    const result = await query(
      `INSERT INTO users (apple_id, email, username, display_name, is_online) 
       VALUES (?, ?, ?, ?, TRUE)`,
      [apple_id, email, username, display_name]
    );

    const userId = result.insertId;

    // Erstelle Standard-Standorteinstellungen
    await query(
      `INSERT INTO location_settings (user_id, visibility, share_location) 
       VALUES (?, 'private', FALSE)`,
      [userId]
    );

    // Generiere JWT Token
    const token = generateToken(userId);

    // Speichere Session
    await query(
      `INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, expires_at) 
       VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [
        userId,
        bcrypt.hashSync(token, 10),
        JSON.stringify(req.headers['user-agent'] || ''),
        req.ip || req.connection.remoteAddress
      ]
    );

    res.status(201).json({
      message: 'Benutzer erfolgreich registriert',
      token,
      user: {
        id: userId,
        username,
        display_name,
        email
      }
    });

  } catch (error) {
    console.error('Registrierungsfehler:', error);
    res.status(500).json({ error: 'Registrierung fehlgeschlagen' });
  }
});

// Apple Sign In Login
router.post('/login', async (req, res) => {
  try {
    const { error, value } = loginSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { apple_id, email } = value;

    // Finde Benutzer
    const user = await query(
      'SELECT id, username, display_name, email, is_active FROM users WHERE apple_id = ? AND email = ? AND is_active = TRUE',
      [apple_id, email]
    );

    if (user.length === 0) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }

    const userData = user[0];

    // Aktualisiere Online-Status
    await query(
      'UPDATE users SET is_online = TRUE, last_seen = NOW() WHERE id = ?',
      [userData.id]
    );

    // Generiere JWT Token
    const token = generateToken(userData.id);

    // Speichere Session
    await query(
      `INSERT INTO user_sessions (user_id, token_hash, device_info, ip_address, expires_at) 
       VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))`,
      [
        userData.id,
        bcrypt.hashSync(token, 10),
        JSON.stringify(req.headers['user-agent'] || ''),
        req.ip || req.connection.remoteAddress
      ]
    );

    res.json({
      message: 'Erfolgreich angemeldet',
      token,
      user: {
        id: userData.id,
        username: userData.username,
        display_name: userData.display_name,
        email: userData.email
      }
    });

  } catch (error) {
    console.error('Anmeldefehler:', error);
    res.status(500).json({ error: 'Anmeldung fehlgeschlagen' });
  }
});

// Logout
router.post('/logout', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Setze Benutzer offline
      await query(
        'UPDATE users SET is_online = FALSE, last_seen = NOW() WHERE id = ?',
        [decoded.userId]
      );

      // Lösche Session
      await query(
        'DELETE FROM user_sessions WHERE user_id = ? AND token_hash = ?',
        [decoded.userId, bcrypt.hashSync(token, 10)]
      );
    }

    res.json({ message: 'Erfolgreich abgemeldet' });
  } catch (error) {
    console.error('Abmeldefehler:', error);
    res.status(500).json({ error: 'Abmeldung fehlgeschlagen' });
  }
});

// Token erneuern
router.post('/refresh', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Token erforderlich' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Überprüfe ob Benutzer noch existiert
    const user = await query(
      'SELECT id, username, display_name, email FROM users WHERE id = ? AND is_active = TRUE',
      [decoded.userId]
    );

    if (user.length === 0) {
      return res.status(401).json({ error: 'Ungültiger Token' });
    }

    // Generiere neuen Token
    const newToken = generateToken(decoded.userId);

    res.json({
      message: 'Token erfolgreich erneuert',
      token: newToken,
      user: user[0]
    });

  } catch (error) {
    console.error('Token-Erneuerungsfehler:', error);
    res.status(401).json({ error: 'Token-Erneuerung fehlgeschlagen' });
  }
});

// Benutzerprofil abrufen
router.get('/profile', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Token erforderlich' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await query(
      `SELECT id, username, display_name, email, profile_picture_url, 
              is_online, last_seen, created_at 
       FROM users WHERE id = ? AND is_active = TRUE`,
      [decoded.userId]
    );

    if (user.length === 0) {
      return res.status(404).json({ error: 'Benutzer nicht gefunden' });
    }

    res.json({ user: user[0] });
  } catch (error) {
    console.error('Profil-Abruf-Fehler:', error);
    res.status(500).json({ error: 'Profil konnte nicht abgerufen werden' });
  }
});

module.exports = router;
