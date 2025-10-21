//
//  AudioProcessor.js
//  WalkiCar Backend - Audio Processing für Gruppen-Voice-Chats
//

class AudioProcessor {
    constructor() {
        this.audioRooms = new Map(); // groupId -> AudioRoom
        this.audioBuffers = new Map(); // userId -> AudioBuffer
        this.mixingInterval = null;
        this.mixIntervalMs = 20; // 20ms = 50fps für Audio
    }

    // Audio-Room für Gruppe erstellen
    createAudioRoom(groupId) {
        if (!this.audioRooms.has(groupId)) {
            this.audioRooms.set(groupId, {
                id: groupId,
                participants: new Set(),
                audioBuffers: new Map(),
                isActive: false,
                createdAt: new Date()
            });
            console.log(`🎤 AudioProcessor: Audio-Room ${groupId} erstellt`);
        }
        return this.audioRooms.get(groupId);
    }

    // Teilnehmer zu Audio-Room hinzufügen
    addParticipant(groupId, userId, socketId) {
        const room = this.createAudioRoom(groupId);
        room.participants.add(userId);
        room.audioBuffers.set(userId, {
            buffer: [],
            lastUpdate: Date.now(),
            socketId: socketId,
            isActive: true
        });
        
        console.log(`🎤 AudioProcessor: User ${userId} zu Audio-Room ${groupId} hinzugefügt`);
        console.log(`🎤 AudioProcessor: Room ${groupId} hat jetzt ${room.participants.size} Teilnehmer`);
        
        return room;
    }

    // Teilnehmer aus Audio-Room entfernen
    removeParticipant(groupId, userId) {
        const room = this.audioRooms.get(groupId);
        if (room) {
            room.participants.delete(userId);
            room.audioBuffers.delete(userId);
            
            console.log(`🎤 AudioProcessor: User ${userId} aus Audio-Room ${groupId} entfernt`);
            console.log(`🎤 AudioProcessor: Room ${groupId} hat jetzt ${room.participants.size} Teilnehmer`);
            
            // Room löschen wenn leer
            if (room.participants.size === 0) {
                this.audioRooms.delete(groupId);
                console.log(`🎤 AudioProcessor: Audio-Room ${groupId} gelöscht (leer)`);
            }
        }
    }

    // Audio-Chunk von Teilnehmer empfangen
    receiveAudioChunk(groupId, userId, audioData, socketId) {
        const room = this.audioRooms.get(groupId);
        if (!room) {
            console.log(`❌ AudioProcessor: Audio-Room ${groupId} nicht gefunden`);
            return;
        }

        const participant = room.audioBuffers.get(userId);
        if (!participant) {
            console.log(`❌ AudioProcessor: User ${userId} nicht in Room ${groupId}`);
            return;
        }

        // Audio-Daten in Buffer speichern
        participant.buffer.push({
            data: audioData,
            timestamp: Date.now()
        });
        participant.lastUpdate = Date.now();
        participant.socketId = socketId;

        // Buffer-Größe begrenzen (letzte 1 Sekunde)
        const maxBufferSize = 50; // 50 * 20ms = 1 Sekunde
        if (participant.buffer.length > maxBufferSize) {
            participant.buffer = participant.buffer.slice(-maxBufferSize);
        }

        // Debug: Audio-Chunk empfangen
        console.log(`🎤 AudioProcessor: Audio-Chunk empfangen von User ${userId} in Room ${groupId} (${audioData.length} Samples)`);

        // Audio-Mixing starten wenn noch nicht aktiv
        if (!this.mixingInterval) {
            this.startAudioMixing();
        }
    }

    // Audio-Mixing starten
    startAudioMixing() {
        if (this.mixingInterval) return;

        this.mixingInterval = setInterval(() => {
            this.processAudioMixing();
        }, this.mixIntervalMs);

        console.log(`🎤 AudioProcessor: Audio-Mixing gestartet (${this.mixIntervalMs}ms Interval)`);
    }

    // Audio-Mixing stoppen
    stopAudioMixing() {
        if (this.mixingInterval) {
            clearInterval(this.mixingInterval);
            this.mixingInterval = null;
            console.log(`🎤 AudioProcessor: Audio-Mixing gestoppt`);
        }
    }

    // Audio-Mixing verarbeiten
    processAudioMixing() {
        const now = Date.now();
        const timeoutMs = 1000; // 1 Sekunde Timeout für inaktive Teilnehmer

        for (const [groupId, room] of this.audioRooms) {
            // Audio auch bei nur einem Teilnehmer verarbeiten (für Echo-Test)
            if (room.participants.size < 1) continue;

            const activeParticipants = [];
            const audioData = [];

            // Aktive Teilnehmer sammeln
            for (const [userId, participant] of room.audioBuffers) {
                if (now - participant.lastUpdate < timeoutMs && participant.buffer.length > 0) {
                    activeParticipants.push(userId);
                    
                    // Neueste Audio-Daten nehmen
                    const latestAudio = participant.buffer[participant.buffer.length - 1];
                    audioData.push({
                        userId: userId,
                        audioData: latestAudio.data,
                        socketId: participant.socketId
                    });
                }
            }

            // Audio an alle anderen Teilnehmer weiterleiten
            if (activeParticipants.length > 0) {
                this.broadcastAudioToRoom(groupId, audioData, room);
            }
        }

        // Mixing stoppen wenn keine aktiven Rooms
        if (this.audioRooms.size === 0) {
            this.stopAudioMixing();
        }
    }

    // Audio an alle Teilnehmer im Room weiterleiten
    broadcastAudioToRoom(groupId, audioData, room) {
        // Audio-Daten an alle anderen Teilnehmer senden
        for (const [userId, participant] of room.audioBuffers) {
            if (participant.isActive) {
                // Audio-Daten für diesen User filtern (nicht seine eigenen)
                const audioForUser = audioData.filter(audio => audio.userId !== userId);
                
                if (audioForUser.length > 0) {
                    // Audio über Socket.IO senden
                    this.sendAudioToParticipant(participant.socketId, {
                        groupId: groupId,
                        audioData: audioForUser,
                        timestamp: Date.now()
                    });
                    console.log(`🎤 AudioProcessor: Audio an User ${userId} gesendet (${audioForUser.length} Streams)`);
                } else if (room.participants.size === 1) {
                    // Echo-Test: Sende eigene Audio-Daten zurück (für Single-User-Test)
                    this.sendAudioToParticipant(participant.socketId, {
                        groupId: groupId,
                        audioData: audioData, // Eigene Audio-Daten für Echo-Test
                        timestamp: Date.now(),
                        isEcho: true
                    });
                    console.log(`🎤 AudioProcessor: Echo-Test Audio an User ${userId} gesendet`);
                }
            }
        }
    }

    // Audio an Teilnehmer senden (wird von Socket.IO überschrieben)
    sendAudioToParticipant(socketId, audioPacket) {
        // Diese Methode wird von der Socket.IO-Implementierung überschrieben
        console.log(`🎤 AudioProcessor: Audio-Packet für Socket ${socketId} bereit`);
    }

    // Audio-Room Status abrufen
    getRoomStatus(groupId) {
        const room = this.audioRooms.get(groupId);
        if (!room) return null;

        return {
            groupId: groupId,
            participantCount: room.participants.size,
            participants: Array.from(room.participants),
            isActive: room.isActive,
            createdAt: room.createdAt
        };
    }

    // Alle Audio-Rooms Status abrufen
    getAllRoomsStatus() {
        const rooms = [];
        for (const [groupId, room] of this.audioRooms) {
            rooms.push(this.getRoomStatus(groupId));
        }
        return rooms;
    }

    // Audio-Room aktivieren/deaktivieren
    setRoomActive(groupId, isActive) {
        const room = this.audioRooms.get(groupId);
        if (room) {
            room.isActive = isActive;
            console.log(`🎤 AudioProcessor: Room ${groupId} ${isActive ? 'aktiviert' : 'deaktiviert'}`);
        }
    }

    // Cleanup für inaktive Teilnehmer
    cleanupInactiveParticipants() {
        const now = Date.now();
        const timeoutMs = 5000; // 5 Sekunden Timeout

        for (const [groupId, room] of this.audioRooms) {
            for (const [userId, participant] of room.audioBuffers) {
                if (now - participant.lastUpdate > timeoutMs) {
                    console.log(`🧹 AudioProcessor: Inaktiven User ${userId} aus Room ${groupId} entfernen`);
                    this.removeParticipant(groupId, userId);
                }
            }
        }
    }
}

module.exports = AudioProcessor;
