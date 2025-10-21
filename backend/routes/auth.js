const express = require('express');
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const Joi = require('joi');
const { query, transaction } = require('../config/database');
const { generateToken } = require('../middleware/auth');

const router = express.Router();

// Validierungsschemas
const registerSchema = Joi.object({
  apple_id: Joi.string().optional(),
  email: Joi.string().email().required(),
  username: Joi.string().alphanum().min(3).max(30).required(),
  display_name: Joi.string().min(1).max(100).required(),
  password: Joi.string().min(8).max(128).optional()
});

const loginSchema = Joi.object({
  apple_id: Joi.string().optional(),
  email: Joi.string().email().required(),
  password: Joi.string().optional()
});

const emailRegisterSchema = Joi.object({
  email: Joi.string().email().required(),
  username: Joi.string().alphanum().min(3).max(30).required(),
  display_name: Joi.string().min(1).max(100).required(),
  password: Joi.string().min(8).max(128).required()
});

const emailLoginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});

const passwordResetSchema = Joi.object({
  email: Joi.string().email().required()
});

const passwordResetConfirmSchema = Joi.object({
  token: Joi.string().required(),
  password: Joi.string().min(8).max(128).required()
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
      `INSERT INTO users (apple_id, email, username, display_name, is_online, auth_provider, email_verified) 
       VALUES (?, ?, ?, ?, TRUE, 'apple', TRUE)`,
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
      message: 'Benutzer erfolgreich registriert. Bitte überprüfe deine E-Mails zur Verifizierung.',
      token,
      user: {
        id: userId,
        username,
        display_name,
        email,
        email_verified: false,
        profile_picture_url: null,
        is_online: false,
        last_seen: null,
        created_at: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Registrierungsfehler:', error);
    res.status(500).json({ error: 'Registrierung fehlgeschlagen' });
  }
});

// Test-Route für Datenbankverbindung
router.get('/test-db', async (req, res) => {
  try {
    const result = await query('SELECT 1 as test');
    res.json({ 
      status: 'OK', 
      database: 'Connected',
      test: result[0].test 
    });
  } catch (error) {
    console.error('Datenbank-Test-Fehler:', error);
    res.status(500).json({ 
      error: 'Datenbankverbindung fehlgeschlagen',
      details: error.message,
      code: error.code
    });
  }
});

// E-Mail/Passwort Registrierung
router.post('/register-email', async (req, res) => {
  try {
    console.log('📧 E-Mail Registrierung gestartet:', req.body);
    
    const { error, value } = emailRegisterSchema.validate(req.body);
    if (error) {
      console.log('❌ Validierungsfehler:', error.details[0].message);
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { email, username, display_name, password } = value;
    console.log('📧 Registrierung - Daten validiert:', { email, username, display_name });

    // Überprüfe ob Benutzer bereits existiert
    console.log('🔍 Prüfe ob Benutzer bereits existiert...');
    const existingUser = await query(
      'SELECT id FROM users WHERE email = ? OR username = ?',
      [email, username]
    );
    console.log('🔍 Existierende Benutzer gefunden:', existingUser.length);

    if (existingUser.length > 0) {
      return res.status(409).json({ error: 'Benutzer existiert bereits' });
    }

    // Hash das Passwort
    const passwordHash = await bcrypt.hash(password, 12);

    // Erstelle neuen Benutzer
    const result = await query(
      `INSERT INTO users (email, username, display_name, password_hash, is_online, auth_provider, email_verified) 
       VALUES (?, ?, ?, ?, TRUE, 'email', FALSE)`,
      [email, username, display_name, passwordHash]
    );

    const userId = result.insertId;

    // Erstelle Standard-Standorteinstellungen
    await query(
      `INSERT INTO location_settings (user_id, visibility, share_location) 
       VALUES (?, 'private', FALSE)`,
      [userId]
    );

    // Generiere E-Mail-Verifizierung-Token
    const verificationToken = require('crypto').randomBytes(32).toString('hex');
    await query(
      `INSERT INTO email_verification_tokens (user_id, token, expires_at) 
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))`,
      [userId, verificationToken]
    );

    // TODO: Hier würde normalerweise eine E-Mail versendet werden
    console.log(`E-Mail-Verifizierung für ${email}: http://localhost:3000/verify-email?token=${verificationToken}`);

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
      message: 'Benutzer erfolgreich registriert. Bitte überprüfe deine E-Mails zur Verifizierung.',
      token,
      user: {
        id: userId,
        username,
        display_name,
        email,
        email_verified: false,
        profile_picture_url: null,
        is_online: true,
        last_seen: new Date().toISOString(),
        created_at: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('❌ E-Mail-Registrierungsfehler:', error);
    console.error('❌ Fehler-Stack:', error.stack);
    res.status(500).json({ 
      error: 'Registrierung fehlgeschlagen', 
      details: error.message,
      type: error.code || 'UNKNOWN_ERROR'
    });
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
        email: userData.email,
        email_verified: true,
        profile_picture_url: null,
        is_online: true,
        last_seen: new Date().toISOString(),
        created_at: null
      }
    });

  } catch (error) {
    console.error('Anmeldefehler:', error);
    res.status(500).json({ error: 'Anmeldung fehlgeschlagen' });
  }
});

// E-Mail/Passwort Login
router.post('/login-email', async (req, res) => {
  try {
    console.log('🔐 E-Mail Login gestartet:', req.body);
    
    const { error, value } = emailLoginSchema.validate(req.body);
    if (error) {
      console.log('❌ Login Validierungsfehler:', error.details[0].message);
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { email, password } = value;
    console.log('🔐 Login - Daten validiert:', { email });

    // Finde Benutzer
    console.log('🔍 Suche Benutzer in Datenbank...');
    const user = await query(
      'SELECT id, username, display_name, email, password_hash, is_active, email_verified FROM users WHERE email = ? AND is_active = TRUE AND auth_provider = "email"',
      [email]
    );
    console.log('🔍 Benutzer gefunden:', user.length > 0 ? 'Ja' : 'Nein');

    if (user.length === 0) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }

    const userData = user[0];

    // Überprüfe Passwort
    const isPasswordValid = await bcrypt.compare(password, userData.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Ungültige Anmeldedaten' });
    }

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
        email: userData.email,
        email_verified: Boolean(userData.email_verified),
        profile_picture_url: null,
        is_online: true,
        last_seen: new Date().toISOString(),
        created_at: null
      }
    });

  } catch (error) {
    console.error('❌ E-Mail-Anmeldefehler:', error);
    console.error('❌ Fehler-Stack:', error.stack);
    res.status(500).json({ 
      error: 'Anmeldung fehlgeschlagen',
      details: error.message,
      type: error.code || 'UNKNOWN_ERROR'
    });
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

// Passwort-Reset anfordern
router.post('/forgot-password', async (req, res) => {
  try {
    const { error, value } = passwordResetSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { email } = value;

    // Finde Benutzer
    const user = await query(
      'SELECT id, email FROM users WHERE email = ? AND is_active = TRUE AND auth_provider = "email"',
      [email]
    );

    if (user.length === 0) {
      // Aus Sicherheitsgründen geben wir immer die gleiche Antwort
      return res.json({ 
        message: 'Falls ein Konto mit dieser E-Mail-Adresse existiert, wurde eine Passwort-Reset-E-Mail gesendet.' 
      });
    }

    const userData = user[0];

    // Generiere Reset-Token
    const resetToken = require('crypto').randomBytes(32).toString('hex');
    
    // Speichere Reset-Token
    await query(
      `INSERT INTO password_reset_tokens (user_id, token, expires_at) 
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR))`,
      [userData.id, resetToken]
    );

    // TODO: Hier würde normalerweise eine E-Mail versendet werden
    console.log(`Passwort-Reset für ${email}: http://localhost:3000/reset-password?token=${resetToken}`);

    res.json({ 
      message: 'Falls ein Konto mit dieser E-Mail-Adresse existiert, wurde eine Passwort-Reset-E-Mail gesendet.' 
    });

  } catch (error) {
    console.error('Passwort-Reset-Fehler:', error);
    res.status(500).json({ error: 'Passwort-Reset fehlgeschlagen' });
  }
});

// Passwort-Reset bestätigen
router.post('/reset-password', async (req, res) => {
  try {
    const { error, value } = passwordResetConfirmSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { token, password } = value;

    // Finde gültigen Reset-Token
    const resetToken = await query(
      `SELECT prt.id, prt.user_id, u.email 
       FROM password_reset_tokens prt
       JOIN users u ON prt.user_id = u.id
       WHERE prt.token = ? AND prt.expires_at > NOW() AND prt.used = FALSE`,
      [token]
    );

    if (resetToken.length === 0) {
      return res.status(400).json({ error: 'Ungültiger oder abgelaufener Reset-Token' });
    }

    const tokenData = resetToken[0];

    // Hash das neue Passwort
    const passwordHash = await bcrypt.hash(password, 12);

    // Aktualisiere Passwort und markiere Token als verwendet
    await transaction([
      {
        sql: 'UPDATE users SET password_hash = ? WHERE id = ?',
        params: [passwordHash, tokenData.user_id]
      },
      {
        sql: 'UPDATE password_reset_tokens SET used = TRUE WHERE id = ?',
        params: [tokenData.id]
      }
    ]);

    res.json({ message: 'Passwort erfolgreich zurückgesetzt' });

  } catch (error) {
    console.error('Passwort-Reset-Bestätigung-Fehler:', error);
    res.status(500).json({ error: 'Passwort-Reset fehlgeschlagen' });
  }
});

// E-Mail-Verifizierung
router.post('/verify-email', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ error: 'Token erforderlich' });
    }

    // Finde gültigen Verifizierungs-Token
    const verificationToken = await query(
      `SELECT evt.id, evt.user_id 
       FROM email_verification_tokens evt
       WHERE evt.token = ? AND evt.expires_at > NOW() AND evt.used = FALSE`,
      [token]
    );

    if (verificationToken.length === 0) {
      return res.status(400).json({ error: 'Ungültiger oder abgelaufener Verifizierungs-Token' });
    }

    const tokenData = verificationToken[0];

    // Markiere E-Mail als verifiziert und Token als verwendet
    await transaction([
      {
        sql: 'UPDATE users SET email_verified = TRUE WHERE id = ?',
        params: [tokenData.user_id]
      },
      {
        sql: 'UPDATE email_verification_tokens SET used = TRUE WHERE id = ?',
        params: [tokenData.id]
      }
    ]);

    res.json({ message: 'E-Mail erfolgreich verifiziert' });

  } catch (error) {
    console.error('E-Mail-Verifizierung-Fehler:', error);
    res.status(500).json({ error: 'E-Mail-Verifizierung fehlgeschlagen' });
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
              is_online, last_seen, created_at, email_verified, auth_provider
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
