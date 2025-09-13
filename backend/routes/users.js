const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const db = require('../config/database');

// Benutzer-Profil abrufen
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Benutzer aus Datenbank abrufen
    const [rows] = await db.execute(
      'SELECT id, username, display_name, email, profile_picture_url, created_at FROM users WHERE id = ?',
      [userId]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Benutzer nicht gefunden' });
    }
    
    const user = rows[0];
    
    res.json({
      id: user.id,
      username: user.username,
      displayName: user.display_name,
      email: user.email,
      profilePictureUrl: user.profile_picture_url,
      createdAt: user.created_at
    });
  } catch (error) {
    console.error('Fehler beim Abrufen des Benutzer-Profils:', error);
    res.status(500).json({ error: 'Interner Serverfehler' });
  }
});

module.exports = router;
