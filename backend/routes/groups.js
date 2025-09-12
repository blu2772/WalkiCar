const express = require('express');
const router = express.Router();
const db = require('../config/database');

// Alle Gruppen des Benutzers abrufen
router.get('/list', async (req, res) => {
  try {
    const userId = req.user.id;
    
    const query = `
      SELECT g.*, 
             COUNT(gm.user_id) as member_count,
             vs.is_active as voice_chat_active,
             vs.started_at as voice_chat_started_at
      FROM groups g
      LEFT JOIN group_members gm ON g.id = gm.group_id
      LEFT JOIN voice_sessions vs ON g.id = vs.group_id AND vs.is_active = true
      WHERE g.id IN (
        SELECT group_id FROM group_members WHERE user_id = ?
      )
      GROUP BY g.id
      ORDER BY g.created_at DESC
    `;
    
    const [groups] = await db.execute(query, [userId]);
    
    // Für jede Gruppe die Mitglieder laden
    for (let group of groups) {
      const membersQuery = `
        SELECT u.id, u.username, u.display_name, u.profile_picture_url, u.is_online,
               gm.role, gm.joined_at,
               vs.is_active as in_voice_chat
        FROM group_members gm
        JOIN users u ON gm.user_id = u.id
        LEFT JOIN voice_sessions vs ON u.id = vs.user_id AND vs.group_id = ? AND vs.is_active = true
        WHERE gm.group_id = ?
        ORDER BY gm.joined_at ASC
      `;
      
      const [members] = await db.execute(membersQuery, [group.id, group.id]);
      group.members = members;
    }
    
    res.json({ groups });
  } catch (error) {
    console.error('Fehler beim Laden der Gruppen:', error);
    res.status(500).json({ error: 'Fehler beim Laden der Gruppen' });
  }
});

// Neue Gruppe erstellen
router.post('/create', async (req, res) => {
  try {
    console.log('🔍 Debug: Gruppen-Erstellung gestartet');
    console.log('🔍 Debug: req.user:', req.user);
    console.log('🔍 Debug: req.body:', req.body);
    
    const userId = req.user.id;
    const { name, description, friendIds } = req.body;
    
    console.log('🔍 Debug: userId:', userId);
    console.log('🔍 Debug: name:', name);
    console.log('🔍 Debug: description:', description);
    console.log('🔍 Debug: friendIds:', friendIds);
    
    if (!name || !friendIds || !Array.isArray(friendIds)) {
      console.log('❌ Debug: Validierung fehlgeschlagen');
      return res.status(400).json({ error: 'Name und Freund-IDs sind erforderlich' });
    }
    
    // Gruppe erstellen
    const createGroupQuery = `
      INSERT INTO groups (name, description, creator_id, is_public, max_members)
      VALUES (?, ?, ?, false, 50)
    `;
    
    console.log('🔍 Debug: Erstelle Gruppe mit Query:', createGroupQuery);
    console.log('🔍 Debug: Parameter:', [name, description, userId]);
    
    const [result] = await db.execute(createGroupQuery, [name, description, userId]);
    const groupId = result.insertId;
    
    console.log('🔍 Debug: Gruppe erstellt mit ID:', groupId);
    
    // Ersteller als Admin hinzufügen
    const addCreatorQuery = `
      INSERT INTO group_members (group_id, user_id, role)
      VALUES (?, ?, 'admin')
    `;
    await db.execute(addCreatorQuery, [groupId, userId]);
    
    // Freunde als Mitglieder hinzufügen
    for (const friendId of friendIds) {
      const addMemberQuery = `
        INSERT INTO group_members (group_id, user_id, role)
        VALUES (?, ?, 'member')
      `;
      await db.execute(addMemberQuery, [groupId, friendId]);
    }
    
    res.json({ 
      success: true, 
      groupId,
      message: 'Gruppe erfolgreich erstellt' 
    });
  } catch (error) {
    console.error('❌ Debug: Fehler beim Erstellen der Gruppe:', error);
    console.error('❌ Debug: Error stack:', error.stack);
    console.error('❌ Debug: Error message:', error.message);
    console.error('❌ Debug: Error code:', error.code);
    res.status(500).json({ error: 'Fehler beim Erstellen der Gruppe' });
  }
});

// Gruppe verlassen
router.post('/:groupId/leave', async (req, res) => {
  try {
    const userId = req.user.id;
    const groupId = req.params.groupId;
    
    // Prüfen ob Benutzer Mitglied der Gruppe ist
    const checkMemberQuery = `
      SELECT role FROM group_members 
      WHERE group_id = ? AND user_id = ?
    `;
    const [members] = await db.execute(checkMemberQuery, [groupId, userId]);
    
    if (members.length === 0) {
      return res.status(403).json({ error: 'Du bist kein Mitglied dieser Gruppe' });
    }
    
    // Aktive Voice Chat Session beenden falls vorhanden
    const endVoiceSessionQuery = `
      UPDATE voice_sessions 
      SET is_active = false, ended_at = NOW()
      WHERE group_id = ? AND user_id = ? AND is_active = true
    `;
    await db.execute(endVoiceSessionQuery, [groupId, userId]);
    
    // Aus Gruppe entfernen
    const leaveGroupQuery = `
      DELETE FROM group_members 
      WHERE group_id = ? AND user_id = ?
    `;
    await db.execute(leaveGroupQuery, [groupId, userId]);
    
    // Prüfen ob Gruppe leer ist und löschen
    const checkEmptyQuery = `
      SELECT COUNT(*) as member_count FROM group_members WHERE group_id = ?
    `;
    const [countResult] = await db.execute(checkEmptyQuery, [groupId]);
    
    if (countResult[0].member_count === 0) {
      const deleteGroupQuery = `DELETE FROM groups WHERE id = ?`;
      await db.execute(deleteGroupQuery, [groupId]);
    }
    
    res.json({ success: true, message: 'Gruppe erfolgreich verlassen' });
  } catch (error) {
    console.error('Fehler beim Verlassen der Gruppe:', error);
    res.status(500).json({ error: 'Fehler beim Verlassen der Gruppe' });
  }
});

// Voice Chat beitreten
router.post('/:groupId/voice/join', async (req, res) => {
  try {
    const userId = req.user.id;
    const groupId = req.params.groupId;
    
    // Prüfen ob Benutzer Mitglied der Gruppe ist
    const checkMemberQuery = `
      SELECT role FROM group_members 
      WHERE group_id = ? AND user_id = ?
    `;
    const [members] = await db.execute(checkMemberQuery, [groupId, userId]);
    
    if (members.length === 0) {
      return res.status(403).json({ error: 'Du bist kein Mitglied dieser Gruppe' });
    }
    
    // Prüfen ob bereits eine aktive Session existiert
    const checkSessionQuery = `
      SELECT id FROM voice_sessions 
      WHERE group_id = ? AND user_id = ? AND is_active = true
    `;
    const [existingSessions] = await db.execute(checkSessionQuery, [groupId, userId]);
    
    if (existingSessions.length > 0) {
      return res.json({ success: true, message: 'Bereits im Voice Chat' });
    }
    
    // Voice Session erstellen
    const createSessionQuery = `
      INSERT INTO voice_sessions (group_id, user_id, session_type, is_active)
      VALUES (?, ?, 'group', true)
    `;
    await db.execute(createSessionQuery, [groupId, userId]);
    
    res.json({ success: true, message: 'Voice Chat beigetreten' });
  } catch (error) {
    console.error('Fehler beim Beitreten zum Voice Chat:', error);
    res.status(500).json({ error: 'Fehler beim Beitreten zum Voice Chat' });
  }
});

// Voice Chat verlassen
router.post('/:groupId/voice/leave', async (req, res) => {
  try {
    const userId = req.user.id;
    const groupId = req.params.groupId;
    
    // Voice Session beenden
    const endSessionQuery = `
      UPDATE voice_sessions 
      SET is_active = false, ended_at = NOW()
      WHERE group_id = ? AND user_id = ? AND is_active = true
    `;
    const [result] = await db.execute(endSessionQuery, [groupId, userId]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Keine aktive Voice Session gefunden' });
    }
    
    res.json({ success: true, message: 'Voice Chat verlassen' });
  } catch (error) {
    console.error('Fehler beim Verlassen des Voice Chats:', error);
    res.status(500).json({ error: 'Fehler beim Verlassen des Voice Chats' });
  }
});

// Voice Chat Status abrufen
router.get('/:groupId/voice/status', async (req, res) => {
  try {
    const groupId = req.params.groupId;
    
    const query = `
      SELECT vs.user_id, u.username, u.display_name, u.profile_picture_url,
             vs.started_at, vs.is_active
      FROM voice_sessions vs
      JOIN users u ON vs.user_id = u.id
      WHERE vs.group_id = ? AND vs.is_active = true
      ORDER BY vs.started_at ASC
    `;
    
    const [participants] = await db.execute(query, [groupId]);
    
    res.json({ 
      participants,
      isActive: participants.length > 0,
      participantCount: participants.length
    });
  } catch (error) {
    console.error('Fehler beim Abrufen des Voice Chat Status:', error);
    res.status(500).json({ error: 'Fehler beim Abrufen des Voice Chat Status' });
  }
});

module.exports = router;
