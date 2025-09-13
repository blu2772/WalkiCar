const express = require('express');
const router = express.Router();
const { query: dbQuery, getConnection } = require('../config/database');

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
    
    const groups = await dbQuery(query, [userId]);
    
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
      
      const members = await dbQuery(membersQuery, [group.id, group.id]);
      group.members = members;
    }
    
    res.json({ groups });
  } catch (error) {
    console.error('❌ Fehler beim Laden der Gruppen:', error);
    
    let errorMessage = 'Fehler beim Laden der Gruppen';
    let errorDetails = {};
    
    if (error.code) errorDetails.code = error.code;
    if (error.sqlMessage) errorDetails.sqlMessage = error.sqlMessage;
    if (error.sql) errorDetails.sql = error.sql;
    if (error.errno) errorDetails.errno = error.errno;
    if (error.sqlState) errorDetails.sqlState = error.sqlState;
    
    // Spezifische Fehlermeldungen
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      errorMessage = 'Datenbanktabelle existiert nicht';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Neue Gruppe erstellen
router.post('/create', async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, description, friendIds } = req.body;
    
    console.log('📝 Gruppen-Erstellung gestartet:', { userId, name, description, friendIds });
    
    if (!name || !friendIds || !Array.isArray(friendIds)) {
      return res.status(400).json({ 
        error: 'Name und Freund-IDs sind erforderlich',
        details: { name: !!name, friendIds: friendIds, isArray: Array.isArray(friendIds) }
      });
    }
    
    // Prüfe ob alle Freunde existieren
    if (friendIds.length > 0) {
      const placeholders = friendIds.map(() => '?').join(',');
      const checkFriendsQuery = `SELECT id FROM users WHERE id IN (${placeholders})`;
      const existingFriends = await dbQuery(checkFriendsQuery, friendIds);
      
      if (existingFriends.length !== friendIds.length) {
        const existingIds = existingFriends.map(f => f.id);
        const missingIds = friendIds.filter(id => !existingIds.includes(id));
        return res.status(400).json({ 
          error: 'Einige Freunde existieren nicht',
          details: { missingFriendIds: missingIds, existingIds }
        });
      }
    }
    
    // Gruppe erstellen
    const createGroupQuery = `
      INSERT INTO groups (name, description, creator_id, is_public, max_members)
      VALUES (?, ?, ?, false, 50)
    `;
    
    console.log('📝 Erstelle Gruppe mit Query:', createGroupQuery, [name, description, userId]);
    const result = await dbQuery(createGroupQuery, [name, description, userId]);
    const groupId = result.insertId;
    
    console.log('✅ Gruppe erstellt mit ID:', groupId);
    
    // Ersteller als Admin hinzufügen
    const addCreatorQuery = `
      INSERT INTO group_members (group_id, user_id, role)
      VALUES (?, ?, 'admin')
    `;
    console.log('📝 Füge Ersteller hinzu:', addCreatorQuery, [groupId, userId]);
    await dbQuery(addCreatorQuery, [groupId, userId]);
    
    // Freunde als Mitglieder hinzufügen (Ersteller ausschließen)
    const uniqueFriendIds = friendIds.filter(id => id !== userId);
    for (const friendId of uniqueFriendIds) {
      const addMemberQuery = `
        INSERT INTO group_members (group_id, user_id, role)
        VALUES (?, ?, 'member')
      `;
      console.log('📝 Füge Freund hinzu:', addMemberQuery, [groupId, friendId]);
      await dbQuery(addMemberQuery, [groupId, friendId]);
    }
    
    console.log('✅ Gruppe erfolgreich erstellt:', groupId);
    res.json({ 
      success: true, 
      groupId,
      message: 'Gruppe erfolgreich erstellt' 
    });
  } catch (error) {
    console.error('❌ Fehler beim Erstellen der Gruppe:', error);
    
    // Detaillierte Fehlermeldung basierend auf Fehlertyp
    let errorMessage = 'Fehler beim Erstellen der Gruppe';
    let errorDetails = {};
    
    if (error.code) {
      errorDetails.code = error.code;
    }
    
    if (error.sqlMessage) {
      errorDetails.sqlMessage = error.sqlMessage;
    }
    
    if (error.sql) {
      errorDetails.sql = error.sql;
    }
    
    if (error.errno) {
      errorDetails.errno = error.errno;
    }
    
    if (error.sqlState) {
      errorDetails.sqlState = error.sqlState;
    }
    
    // Spezifische Fehlermeldungen für häufige Probleme
    if (error.code === 'ER_DUP_ENTRY') {
      errorMessage = 'Gruppe mit diesem Namen existiert bereits';
    } else if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = 'Referenzierter Benutzer existiert nicht';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
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
    const members = await dbQuery(checkMemberQuery, [groupId, userId]);
    
    if (members.length === 0) {
      return res.status(403).json({ error: 'Du bist kein Mitglied dieser Gruppe' });
    }
    
    // Aktive Voice Chat Session beenden falls vorhanden
    const endVoiceSessionQuery = `
      UPDATE voice_sessions 
      SET is_active = false, ended_at = NOW()
      WHERE group_id = ? AND user_id = ? AND is_active = true
    `;
    await dbQuery(endVoiceSessionQuery, [groupId, userId]);
    
    // Aus Gruppe entfernen
    const leaveGroupQuery = `
      DELETE FROM group_members 
      WHERE group_id = ? AND user_id = ?
    `;
    await dbQuery(leaveGroupQuery, [groupId, userId]);
    
    // Prüfen ob Gruppe leer ist und löschen
    const checkEmptyQuery = `
      SELECT COUNT(*) as member_count FROM group_members WHERE group_id = ?
    `;
    const countResult = await dbQuery(checkEmptyQuery, [groupId]);
    
    if (countResult[0].member_count === 0) {
      const deleteGroupQuery = `DELETE FROM groups WHERE id = ?`;
      await dbQuery(deleteGroupQuery, [groupId]);
    }
    
    res.json({ success: true, message: 'Gruppe erfolgreich verlassen' });
  } catch (error) {
    console.error('❌ Fehler beim Verlassen der Gruppe:', error);
    
    let errorMessage = 'Fehler beim Verlassen der Gruppe';
    let errorDetails = {};
    
    if (error.code) errorDetails.code = error.code;
    if (error.sqlMessage) errorDetails.sqlMessage = error.sqlMessage;
    if (error.sql) errorDetails.sql = error.sql;
    if (error.errno) errorDetails.errno = error.errno;
    if (error.sqlState) errorDetails.sqlState = error.sqlState;
    
    // Spezifische Fehlermeldungen
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      errorMessage = 'Datenbanktabelle existiert nicht';
    } else if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = 'Referenzierter Datensatz existiert nicht';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
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
    const members = await dbQuery(checkMemberQuery, [groupId, userId]);
    
    if (members.length === 0) {
      return res.status(403).json({ error: 'Du bist kein Mitglied dieser Gruppe' });
    }
    
    // Prüfen ob bereits eine aktive Session existiert
    const checkSessionQuery = `
      SELECT id FROM voice_sessions 
      WHERE group_id = ? AND user_id = ? AND is_active = true
    `;
    const existingSessions = await dbQuery(checkSessionQuery, [groupId, userId]);
    
    if (existingSessions.length > 0) {
      return res.json({ success: true, message: 'Bereits im Voice Chat' });
    }
    
    // Voice Session erstellen
    const createSessionQuery = `
      INSERT INTO voice_sessions (group_id, user_id, session_type, is_active)
      VALUES (?, ?, 'group', true)
    `;
    await dbQuery(createSessionQuery, [groupId, userId]);
    
    // Benachrichtige alle Gruppenmitglieder über den Voice Chat Beitritt
    const getGroupMembersQuery = `
      SELECT user_id FROM group_members WHERE group_id = ?
    `;
    const groupMembers = await dbQuery(getGroupMembersQuery, [groupId]);
    
    // Sende WebSocket Event an alle Gruppenmitglieder
    const io = req.app.get('io');
    if (io) {
      console.log(`🎤 Sende user_joined_voice_chat Event für Gruppe ${groupId} an ${groupMembers.length} Mitglieder`);
      groupMembers.forEach(member => {
        console.log(`🎤 Sende Event an user_${member.user_id}`);
        io.to(`user_${member.user_id}`).emit('user_joined_voice_chat', {
          groupId: parseInt(groupId),
          userId: userId,
          username: req.user.username,
          displayName: req.user.display_name
        });
      });
      
      // Zusätzlich: Sende Event an Gruppen-Raum
      console.log(`🎤 Sende user_joined_voice_chat Event an Gruppen-Raum group_${groupId}`);
      io.to(`group_${groupId}`).emit('user_joined_voice_chat', {
        groupId: parseInt(groupId),
        userId: userId,
        username: req.user.username,
        displayName: req.user.display_name
      });
      
      // Zusätzlich: Sende Event an Voice Chat Raum
      console.log(`🎤 Sende user_joined_voice_chat Event an Voice Chat Raum voice_chat_${groupId}`);
      io.to(`voice_chat_${groupId}`).emit('user_joined_voice_chat', {
        groupId: parseInt(groupId),
        userId: userId,
        username: req.user.username,
        displayName: req.user.display_name
      });
    } else {
      console.log('❌ Socket.IO nicht verfügbar für user_joined_voice_chat Event');
    }
    
    res.json({ success: true, message: 'Voice Chat beigetreten' });
  } catch (error) {
    console.error('❌ Fehler beim Beitreten zum Voice Chat:', error);
    
    let errorMessage = 'Fehler beim Beitreten zum Voice Chat';
    let errorDetails = {};
    
    if (error.code) errorDetails.code = error.code;
    if (error.sqlMessage) errorDetails.sqlMessage = error.sqlMessage;
    if (error.sql) errorDetails.sql = error.sql;
    if (error.errno) errorDetails.errno = error.errno;
    if (error.sqlState) errorDetails.sqlState = error.sqlState;
    
    // Spezifische Fehlermeldungen
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      errorMessage = 'Datenbanktabelle existiert nicht';
    } else if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = 'Referenzierter Datensatz existiert nicht';
    } else if (error.code === 'ER_DUP_ENTRY') {
      errorMessage = 'Voice Chat Session bereits vorhanden';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
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
    const result = await dbQuery(endSessionQuery, [groupId, userId]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Keine aktive Voice Session gefunden' });
    }
    
    // Benachrichtige alle Gruppenmitglieder über das Verlassen des Voice Chats
    const getGroupMembersQuery = `
      SELECT user_id FROM group_members WHERE group_id = ?
    `;
    const groupMembers = await dbQuery(getGroupMembersQuery, [groupId]);
    
    // Sende WebSocket Event an alle Gruppenmitglieder
    const io = req.app.get('io');
    if (io) {
      console.log(`🎤 Sende user_left_voice_chat Event für Gruppe ${groupId} an ${groupMembers.length} Mitglieder`);
      groupMembers.forEach(member => {
        console.log(`🎤 Sende Event an user_${member.user_id}`);
        io.to(`user_${member.user_id}`).emit('user_left_voice_chat', {
          groupId: parseInt(groupId),
          userId: userId,
          username: req.user.username,
          displayName: req.user.display_name
        });
      });
      
      // Zusätzlich: Sende Event an Gruppen-Raum
      console.log(`🎤 Sende user_left_voice_chat Event an Gruppen-Raum group_${groupId}`);
      io.to(`group_${groupId}`).emit('user_left_voice_chat', {
        groupId: parseInt(groupId),
        userId: userId,
        username: req.user.username,
        displayName: req.user.display_name
      });
      
      // Zusätzlich: Sende Event an Voice Chat Raum
      console.log(`🎤 Sende user_left_voice_chat Event an Voice Chat Raum voice_chat_${groupId}`);
      io.to(`voice_chat_${groupId}`).emit('user_left_voice_chat', {
        groupId: parseInt(groupId),
        userId: userId,
        username: req.user.username,
        displayName: req.user.display_name
      });
    } else {
      console.log('❌ Socket.IO nicht verfügbar für user_left_voice_chat Event');
    }
    
    res.json({ success: true, message: 'Voice Chat verlassen' });
  } catch (error) {
    console.error('❌ Fehler beim Verlassen des Voice Chats:', error);
    
    let errorMessage = 'Fehler beim Verlassen des Voice Chats';
    let errorDetails = {};
    
    if (error.code) errorDetails.code = error.code;
    if (error.sqlMessage) errorDetails.sqlMessage = error.sqlMessage;
    if (error.sql) errorDetails.sql = error.sql;
    if (error.errno) errorDetails.errno = error.errno;
    if (error.sqlState) errorDetails.sqlState = error.sqlState;
    
    // Spezifische Fehlermeldungen
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      errorMessage = 'Datenbanktabelle existiert nicht';
    } else if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = 'Referenzierter Datensatz existiert nicht';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
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
    
    const participants = await dbQuery(query, [groupId]);
    
    res.json({ 
      participants,
      isActive: participants.length > 0,
      participantCount: participants.length
    });
  } catch (error) {
    console.error('❌ Fehler beim Abrufen des Voice Chat Status:', error);
    
    let errorMessage = 'Fehler beim Abrufen des Voice Chat Status';
    let errorDetails = {};
    
    if (error.code) errorDetails.code = error.code;
    if (error.sqlMessage) errorDetails.sqlMessage = error.sqlMessage;
    if (error.sql) errorDetails.sql = error.sql;
    if (error.errno) errorDetails.errno = error.errno;
    if (error.sqlState) errorDetails.sqlState = error.sqlState;
    
    // Spezifische Fehlermeldungen
    if (error.code === 'ECONNREFUSED') {
      errorMessage = 'Datenbankverbindung fehlgeschlagen';
    } else if (error.code === 'ER_ACCESS_DENIED_ERROR') {
      errorMessage = 'Datenbankzugriff verweigert';
    } else if (error.code === 'ER_BAD_FIELD_ERROR') {
      errorMessage = 'Ungültiges Datenbankfeld';
    } else if (error.code === 'ER_NO_SUCH_TABLE') {
      errorMessage = 'Datenbanktabelle existiert nicht';
    } else if (error.code === 'ER_NO_REFERENCED_ROW_2') {
      errorMessage = 'Referenzierter Datensatz existiert nicht';
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: errorDetails,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

module.exports = router;
