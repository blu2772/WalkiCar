const express = require('express');
const Joi = require('joi');
const { query, transaction } = require('../config/database');

const router = express.Router();

// Validierungsschemas
const friendRequestSchema = Joi.object({
  friend_username: Joi.string().alphanum().min(3).max(30).required()
});

const friendActionSchema = Joi.object({
  friendship_id: Joi.number().integer().positive().required(),
  action: Joi.string().valid('accept', 'decline', 'block').required()
});

// Freundschaftsanfrage senden
router.post('/request', async (req, res) => {
  try {
    const { error, value } = friendRequestSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { friend_username } = value;
    const userId = req.user.id;

    // Überprüfe ob der Freund existiert
    const friend = await query(
      'SELECT id, username, display_name FROM users WHERE username = ? AND is_active = TRUE',
      [friend_username]
    );

    if (friend.length === 0) {
      return res.status(404).json({ error: 'Benutzer nicht gefunden' });
    }

    const friendData = friend[0];

    // Überprüfe ob es sich nicht um sich selbst handelt
    if (friendData.id === userId) {
      return res.status(400).json({ error: 'Du kannst dir nicht selbst eine Freundschaftsanfrage senden' });
    }

    // Überprüfe ob bereits eine Freundschaft existiert
    const existingFriendship = await query(
      'SELECT id, status FROM friendships WHERE (user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
      [userId, friendData.id, friendData.id, userId]
    );

    if (existingFriendship.length > 0) {
      const friendship = existingFriendship[0];
      switch (friendship.status) {
        case 'pending':
          return res.status(409).json({ error: 'Freundschaftsanfrage bereits ausstehend' });
        case 'accepted':
          return res.status(409).json({ error: 'Ihr seid bereits befreundet' });
        case 'blocked':
          return res.status(403).json({ error: 'Diese Freundschaft ist blockiert' });
        case 'declined':
          // Erlaube neue Anfrage nach Ablehnung
          break;
      }
    }

    // Erstelle Freundschaftsanfrage
    await query(
      'INSERT INTO friendships (user_id, friend_id, status) VALUES (?, ?, ?)',
      [userId, friendData.id, 'pending']
    );

    // Erstelle Benachrichtigung für den Freund
    await query(
      `INSERT INTO notifications (user_id, type, title, message, data) 
       VALUES (?, 'friend_request', 'Neue Freundschaftsanfrage', 
               '${req.user.username} möchte dein Freund werden', 
               ?)`,
      [friendData.id, JSON.stringify({ from_user_id: userId, from_username: req.user.username })]
    );

    res.status(201).json({
      message: 'Freundschaftsanfrage erfolgreich gesendet',
      friend: {
        id: friendData.id,
        username: friendData.username,
        display_name: friendData.display_name
      }
    });

  } catch (error) {
    console.error('Freundschaftsanfrage-Fehler:', error);
    res.status(500).json({ error: 'Freundschaftsanfrage konnte nicht gesendet werden' });
  }
});

// Ausstehende Freundschaftsanfragen abrufen
router.get('/requests', async (req, res) => {
  try {
    const userId = req.user.id;

    const requests = await query(
      `SELECT f.id, f.created_at, u.id as user_id, u.username, u.display_name, u.profile_picture_url
       FROM friendships f
       JOIN users u ON f.user_id = u.id
       WHERE f.friend_id = ? AND f.status = 'pending'
       ORDER BY f.created_at DESC`,
      [userId]
    );

    res.json({ requests });
  } catch (error) {
    console.error('Freundschaftsanfragen-Abruf-Fehler:', error);
    res.status(500).json({ error: 'Freundschaftsanfragen konnten nicht abgerufen werden' });
  }
});

// Freundschaftsanfrage bearbeiten (annehmen/ablehnen/blockieren)
router.put('/action', async (req, res) => {
  try {
    const { error, value } = friendActionSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ 
        error: 'Ungültige Eingabedaten', 
        details: error.details[0].message 
      });
    }

    const { friendship_id, action } = value;
    const userId = req.user.id;

    // Überprüfe ob die Freundschaftsanfrage existiert und dem Benutzer gehört
    const friendship = await query(
      'SELECT id, user_id, friend_id, status FROM friendships WHERE id = ? AND friend_id = ?',
      [friendship_id, userId]
    );

    if (friendship.length === 0) {
      return res.status(404).json({ error: 'Freundschaftsanfrage nicht gefunden' });
    }

    const friendshipData = friendship[0];

    if (friendshipData.status !== 'pending') {
      return res.status(400).json({ error: 'Freundschaftsanfrage wurde bereits bearbeitet' });
    }

    // Führe die Aktion aus
    await transaction([
      {
        sql: 'UPDATE friendships SET status = ? WHERE id = ?',
        params: [action, friendship_id]
      }
    ]);

    // Wenn angenommen, erstelle Benachrichtigung für den ursprünglichen Sender
    if (action === 'accept') {
      await query(
        `INSERT INTO notifications (user_id, type, title, message, data) 
         VALUES (?, 'friend_accepted', 'Freundschaftsanfrage angenommen', 
                 '${req.user.username} hat deine Freundschaftsanfrage angenommen', 
                 ?)`,
        [friendshipData.user_id, JSON.stringify({ friend_id: userId, friend_username: req.user.username })]
      );
    }

    res.json({ 
      message: `Freundschaftsanfrage ${action === 'accept' ? 'angenommen' : action === 'decline' ? 'abgelehnt' : 'blockiert'}` 
    });

  } catch (error) {
    console.error('Freundschaftsaktion-Fehler:', error);
    res.status(500).json({ error: 'Aktion konnte nicht ausgeführt werden' });
  }
});

// Debug-Route für Freundschaften
router.get('/debug-friendships', async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Alle Freundschaften für diesen Benutzer
    const allFriendships = await query(
      'SELECT * FROM friendships WHERE user_id = ? OR friend_id = ? ORDER BY created_at DESC',
      [userId, userId]
    );
    
    // Benutzer-Info
    const userInfo = await query(
      'SELECT id, username, display_name FROM users WHERE id = ?',
      [userId]
    );
    
    res.json({
      user: userInfo[0],
      all_friendships: allFriendships,
      count: allFriendships.length
    });
  } catch (error) {
    console.error('Debug-Freundschaften-Fehler:', error);
    res.status(500).json({ 
      error: 'Debug-Fehler',
      details: error.message
    });
  }
});

// Freundesliste abrufen
router.get('/list', async (req, res) => {
  try {
    const userId = req.user.id;

    const friends = await query(
      `SELECT f.id as friendship_id, u.id, u.username, u.display_name, 
              u.profile_picture_url, u.is_online, u.last_seen,
              c.id as active_car_id, c.name as active_car_name, c.brand, c.model, c.color
       FROM friendships f
       JOIN users u ON (f.user_id = u.id OR f.friend_id = u.id)
       LEFT JOIN cars c ON (u.id = c.user_id AND c.is_active = TRUE)
       WHERE (f.user_id = ? OR f.friend_id = ?) 
         AND f.status = 'accepted' 
         AND u.id != ?
       ORDER BY u.is_online DESC, u.last_seen DESC`,
      [userId, userId, userId]
    );

    // Formatiere die Daten
    const formattedFriends = friends.map(friend => ({
      friendship_id: friend.friendship_id,
      id: friend.id,
      username: friend.username,
      display_name: friend.display_name,
      profile_picture_url: friend.profile_picture_url,
      is_online: friend.is_online,
      last_seen: friend.last_seen,
      active_car: friend.active_car_id ? {
        id: friend.active_car_id,
        name: friend.active_car_name,
        brand: friend.brand,
        model: friend.model,
        color: friend.color
      } : null
    }));

    res.json({ friends: formattedFriends });
  } catch (error) {
    console.error('Freundesliste-Abruf-Fehler:', error);
    res.status(500).json({ error: 'Freundesliste konnte nicht abgerufen werden' });
  }
});

// Freund entfernen
router.delete('/remove/:friendship_id', async (req, res) => {
  try {
    const { friendship_id } = req.params;
    const userId = req.user.id;

    // Überprüfe ob die Freundschaft existiert und dem Benutzer gehört
    const friendship = await query(
      'SELECT id FROM friendships WHERE id = ? AND (user_id = ? OR friend_id = ?) AND status = "accepted"',
      [friendship_id, userId, userId]
    );

    if (friendship.length === 0) {
      return res.status(404).json({ error: 'Freundschaft nicht gefunden' });
    }

    // Lösche die Freundschaft
    await query('DELETE FROM friendships WHERE id = ?', [friendship_id]);

    res.json({ message: 'Freundschaft erfolgreich beendet' });
  } catch (error) {
    console.error('Freund-Entfernen-Fehler:', error);
    res.status(500).json({ error: 'Freund konnte nicht entfernt werden' });
  }
});

// Blockierte Freunde abrufen
router.get('/blocked', async (req, res) => {
  try {
    const userId = req.user.id;

    const blockedFriends = await query(
      `SELECT f.id as friendship_id, u.id, u.username, u.display_name, 
              u.profile_picture_url, f.created_at as blocked_at
       FROM friendships f
       JOIN users u ON (f.user_id = u.id OR f.friend_id = u.id)
       WHERE (f.user_id = ? OR f.friend_id = ?) 
         AND f.status = 'blocked' 
         AND u.id != ?
       ORDER BY f.updated_at DESC`,
      [userId, userId, userId]
    );

    res.json({ blocked_friends: blockedFriends });
  } catch (error) {
    console.error('Blockierte-Freunde-Abruf-Fehler:', error);
    res.status(500).json({ error: 'Blockierte Freunde konnten nicht abgerufen werden' });
  }
});

// Freund entsperren
router.put('/unblock/:friendship_id', async (req, res) => {
  try {
    const { friendship_id } = req.params;
    const userId = req.user.id;

    // Überprüfe ob die blockierte Freundschaft existiert
    const friendship = await query(
      'SELECT id FROM friendships WHERE id = ? AND (user_id = ? OR friend_id = ?) AND status = "blocked"',
      [friendship_id, userId, userId]
    );

    if (friendship.length === 0) {
      return res.status(404).json({ error: 'Blockierte Freundschaft nicht gefunden' });
    }

    // Lösche die blockierte Freundschaft (entsperren)
    await query('DELETE FROM friendships WHERE id = ?', [friendship_id]);

    res.json({ message: 'Freund erfolgreich entsperrt' });
  } catch (error) {
    console.error('Freund-Entsperren-Fehler:', error);
    res.status(500).json({ error: 'Freund konnte nicht entsperrt werden' });
  }
});

// Benutzer suchen (für Freundschaftsanfragen)
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;
    const userId = req.user.id;

    if (!q || q.length < 2) {
      return res.status(400).json({ error: 'Suchbegriff muss mindestens 2 Zeichen lang sein' });
    }

    const users = await query(
      `SELECT u.id, u.username, u.display_name, u.profile_picture_url, u.is_online,
              CASE 
                WHEN f1.status = 'accepted' THEN 'friend'
                WHEN f1.status = 'pending' THEN 'pending'
                WHEN f1.status = 'blocked' THEN 'blocked'
                WHEN f2.status = 'pending' THEN 'requested'
                ELSE 'none'
              END as relationship_status
       FROM users u
       LEFT JOIN friendships f1 ON (f1.user_id = ? AND f1.friend_id = u.id)
       LEFT JOIN friendships f2 ON (f2.user_id = u.id AND f2.friend_id = ?)
       WHERE u.is_active = TRUE 
         AND u.id != ?
         AND (u.username LIKE ? OR u.display_name LIKE ?)
       ORDER BY u.is_online DESC, u.username ASC
       LIMIT 20`,
      [userId, userId, userId, `%${q}%`, `%${q}%`]
    );

    res.json({ users });
  } catch (error) {
    console.error('Benutzer-Suche-Fehler:', error);
    res.status(500).json({ 
      error: 'Suche konnte nicht durchgeführt werden',
      details: error.message,
      type: error.code || 'UNKNOWN_ERROR'
    });
  }
});

module.exports = router;
