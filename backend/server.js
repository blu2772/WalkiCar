const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { createServer } = require('http');
const { createServer: createHttpsServer } = require('https');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const friendRoutes = require('./routes/friends');
const carRoutes = require('./routes/cars');
const groupRoutes = require('./routes/groups');
const locationRoutes = require('./routes/locations');

const { connectDB } = require('./config/database');
const { authenticateToken } = require('./middleware/auth');

const app = express();

// HTTPS-Konfiguration
let server;
let httpsOptions = null;

// Prüfe ob SSL-Zertifikate vorhanden sind
// Plesk SSL-Zertifikat-Pfade (verschiedene mögliche Pfade)
const pleskCertPaths = [
  '/usr/local/psa/var/certificates/cert-timrmp.de',
  '/usr/local/psa/var/certificates/scf-timrmp.de'
];

const pleskKeyPaths = [
  '/usr/local/psa/var/certificates/cert-timrmp.de.key',
  '/usr/local/psa/var/certificates/scf-timrmp.de.key'
];

// Alternative: Let's Encrypt Pfade
const letsEncryptCertPath = '/etc/letsencrypt/live/timrmp.de/fullchain.pem';
const letsEncryptKeyPath = '/etc/letsencrypt/live/timrmp.de/privkey.pem';

// Debug: Alle möglichen Pfade auflisten
console.log('🔍 Suche nach SSL-Zertifikaten...');
console.log('📁 Prüfe Plesk-Zertifikat-Pfade:');
pleskCertPaths.forEach(path => {
  console.log(`   ${fs.existsSync(path) ? '✅' : '❌'} ${path}`);
});

console.log('📁 Prüfe Plesk-Key-Pfade:');
pleskKeyPaths.forEach(path => {
  console.log(`   ${fs.existsSync(path) ? '✅' : '❌'} ${path}`);
});

console.log('📁 Prüfe Let\'s Encrypt-Pfade:');
console.log(`   ${fs.existsSync(letsEncryptCertPath) ? '✅' : '❌'} ${letsEncryptCertPath}`);
console.log(`   ${fs.existsSync(letsEncryptKeyPath) ? '✅' : '❌'} ${letsEncryptKeyPath}`);

// Prüfe zuerst Plesk, dann Let's Encrypt
let finalCertPath, finalKeyPath;

// Suche nach Plesk-Zertifikaten
for (let i = 0; i < pleskCertPaths.length; i++) {
  const certPath = pleskCertPaths[i];
  const keyPath = pleskKeyPaths[i];
  
  if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
    finalCertPath = certPath;
    finalKeyPath = keyPath;
    console.log('🔒 Plesk SSL-Zertifikat gefunden:', certPath);
    break;
  }
}

// Fallback: Let's Encrypt
if (!finalCertPath && fs.existsSync(letsEncryptCertPath) && fs.existsSync(letsEncryptKeyPath)) {
  finalCertPath = letsEncryptCertPath;
  finalKeyPath = letsEncryptKeyPath;
  console.log('🔒 Let\'s Encrypt SSL-Zertifikat gefunden');
}

// Plesk Reverse Proxy verwendet - HTTP ist ausreichend
console.log('🔄 Plesk Reverse Proxy Modus - HTTP verwendet');
server = createServer(app);

const io = new Server(server, {
  cors: {
    origin: process.env.SOCKET_CORS_ORIGIN || "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? 'https://walkcar.timrmp.de' : 'http://localhost:3000',
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100, // limit each IP to 100 requests per windowMs
  message: 'Zu viele Anfragen von dieser IP, bitte versuchen Sie es später erneut.'
});
app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Static files
app.use('/uploads', express.static('uploads'));

// Socket.IO an App weitergeben (vor Routen-Registrierung)
app.set('io', io);

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authenticateToken, userRoutes);
app.use('/api/friends', authenticateToken, friendRoutes);
app.use('/api/cars', authenticateToken, carRoutes);
app.use('/api/groups', authenticateToken, groupRoutes);
app.use('/api/locations', authenticateToken, locationRoutes);

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.2',
    socketAuth: 'DISABLED_FOR_TESTING'
  });
});

// Socket.IO connection handling - TEMPORÄR DEAKTIVIERT ZUM TESTEN
io.use(async (socket, next) => {
  console.log('🔓 Socket.IO: Authentifizierung temporär deaktiviert - alle Verbindungen erlaubt');
  console.log('🔓 Socket.IO: Token in Query:', socket.handshake.query.token ? 'Vorhanden' : 'Nicht vorhanden');
  
  // Temporär alle Verbindungen erlauben
  socket.userId = 7; // Hardcoded für Test
  socket.user = { id: 7, username: 'TimRempel', display_name: 'Tim.rmp' };
  
  next();
});

io.on('connection', (socket) => {
  console.log('🔌 Socket.IO: Benutzer verbunden:', socket.id, 'User:', socket.user?.username);
  
  // Benutzer-Raum beitreten
  socket.on('join_user_room', async (data) => {
    try {
      const { userId } = data;
      
      // Join user-specific room for direct communication
      socket.join(`user_${userId}`);
      console.log(`👤 Socket.IO: User ${socket.id} joined user room for user ${userId}`);
    } catch (error) {
      console.error('❌ Socket.IO: Error joining user room:', error);
    }
  });

  // Gruppen-Raum beitreten
  socket.on('join_group_room', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Join group-specific room
      socket.join(`group_${groupId}`);
      console.log(`👥 Socket.IO: User ${socket.id} joined group room ${groupId}`);
    } catch (error) {
      console.error('❌ Socket.IO: Error joining group room:', error);
    }
  });

  // Voice Chat beitreten
  socket.on('join_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Join voice chat room
      socket.join(`voice_chat_${groupId}`);
      console.log(`🎤 Socket.IO: User ${socket.id} joined voice chat for group ${groupId}`);
    } catch (error) {
      console.error('❌ Socket.IO: Error joining voice chat:', error);
    }
  });

  // Voice Chat verlassen
  socket.on('leave_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Leave voice chat room
      socket.leave(`voice_chat_${groupId}`);
      console.log(`🎤 Socket.IO: User ${socket.id} left voice chat for group ${groupId}`);
    } catch (error) {
      console.error('❌ Socket.IO: Error leaving voice chat:', error);
    }
  });
  
  socket.on('join_room', (roomId) => {
    socket.join(roomId);
    console.log(`User ${socket.id} joined room ${roomId}`);
  });
  
  socket.on('leave_room', (roomId) => {
    socket.leave(roomId);
    console.log(`User ${socket.id} left room ${roomId}`);
  });
  
  socket.on('disconnect', () => {
    console.log('🔌 Socket.IO: Benutzer getrennt:', socket.id);
  });
  
  // Location tracking events
  socket.on('start_location_tracking', async (data) => {
    try {
      const { userId, carId } = data;
      console.log(`User ${userId} started location tracking for car ${carId}`);
      
      // Join location tracking room
      socket.join(`location_tracking_${userId}`);
      
      // Broadcast to friends that user is now live
      socket.to(`friends_of_${userId}`).emit('friend_went_live', {
        userId,
        carId,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error starting location tracking:', error);
      socket.emit('location_tracking_error', { error: error.message });
    }
  });
  
  socket.on('stop_location_tracking', async (data) => {
    try {
      const { userId, carId } = data;
      console.log(`User ${userId} stopped location tracking for car ${carId}`);
      
      // Leave location tracking room
      socket.leave(`location_tracking_${userId}`);
      
      // Broadcast to friends that user parked
      socket.to(`friends_of_${userId}`).emit('friend_parked', {
        userId,
        carId,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error stopping location tracking:', error);
      socket.emit('location_tracking_error', { error: error.message });
    }
  });
  
  socket.on('location_update', async (data) => {
    try {
      const { userId, carId, latitude, longitude, accuracy, speed, heading, altitude, bluetoothConnected } = data;
      
      // Broadcast location update to friends
      socket.to(`friends_of_${userId}`).emit('friend_location_update', {
        userId,
        carId,
        latitude,
        longitude,
        accuracy,
        speed,
        heading,
        altitude,
        bluetoothConnected,
        timestamp: new Date().toISOString()
      });
      
      console.log(`Location update from user ${userId}: ${latitude}, ${longitude}`);
    } catch (error) {
      console.error('Error processing location update:', error);
    }
  });
  
  socket.on('join_friends_room', async (data) => {
    try {
      const { userId } = data;
      
      // Join friends room to receive updates
      socket.join(`friends_of_${userId}`);
      console.log(`User ${socket.id} joined friends room for user ${userId}`);
    } catch (error) {
      console.error('Error joining friends room:', error);
    }
  });
  
  // Voice Chat Events
  socket.on('join_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      console.log(`User ${userId} joining group voice chat ${groupId}`);
      
      // Join group voice chat room
      socket.join(`group_voice_${groupId}`);
      
      // Broadcast to other group members that user joined voice chat
      socket.to(`group_voice_${groupId}`).emit('user_joined_voice_chat', {
        userId,
        groupId,
        timestamp: new Date().toISOString()
      });
      
      // Broadcast to group members that voice chat is now active
      socket.to(`group_members_${groupId}`).emit('voice_chat_started', {
        groupId,
        userId,
        timestamp: new Date().toISOString()
      });
      
    } catch (error) {
      console.error('Error joining group voice chat:', error);
      socket.emit('voice_chat_error', { error: error.message });
    }
  });
  
  socket.on('leave_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      console.log(`User ${userId} leaving group voice chat ${groupId}`);
      
      // Leave group voice chat room
      socket.leave(`group_voice_${groupId}`);
      
      // Broadcast to other group members that user left voice chat
      socket.to(`group_voice_${groupId}`).emit('user_left_voice_chat', {
        userId,
        groupId,
        timestamp: new Date().toISOString()
      });
      
      // Check if voice chat is now empty and broadcast accordingly
      const room = io.sockets.adapter.rooms.get(`group_voice_${groupId}`);
      if (!room || room.size === 0) {
        socket.to(`group_members_${groupId}`).emit('voice_chat_ended', {
          groupId,
          timestamp: new Date().toISOString()
        });
      }
      
    } catch (error) {
      console.error('Error leaving group voice chat:', error);
      socket.emit('voice_chat_error', { error: error.message });
    }
  });
  
  socket.on('join_group_room', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Join group room to receive group updates
      socket.join(`group_members_${groupId}`);
      console.log(`User ${socket.id} joined group room for group ${groupId}`);
    } catch (error) {
      console.error('Error joining group room:', error);
    }
  });
  
  // WebRTC Signaling Events
  socket.on('webrtc_offer', async (data) => {
    try {
      const { targetUserId, groupId, offer } = data;
      console.log(`WebRTC offer from ${socket.id} to user ${targetUserId} in group ${groupId}`);
      
      // Forward offer to target user
      socket.to(`user_${targetUserId}`).emit('webrtc_offer', {
        fromUserId: data.fromUserId,
        groupId: groupId,
        offer: offer
      });
    } catch (error) {
      console.error('Error handling WebRTC offer:', error);
    }
  });
  
  socket.on('webrtc_answer', async (data) => {
    try {
      const { targetUserId, groupId, answer } = data;
      console.log(`WebRTC answer from ${socket.id} to user ${targetUserId} in group ${groupId}`);
      
      // Forward answer to target user
      socket.to(`user_${targetUserId}`).emit('webrtc_answer', {
        fromUserId: data.fromUserId,
        groupId: groupId,
        answer: answer
      });
    } catch (error) {
      console.error('Error handling WebRTC answer:', error);
    }
  });
  
  socket.on('webrtc_ice_candidate', async (data) => {
    try {
      const { targetUserId, groupId, candidate } = data;
      console.log(`WebRTC ICE candidate from ${socket.id} to user ${targetUserId} in group ${groupId}`);
      
      // Forward ICE candidate to target user
      socket.to(`user_${targetUserId}`).emit('webrtc_ice_candidate', {
        fromUserId: data.fromUserId,
        groupId: groupId,
        candidate: candidate
      });
    } catch (error) {
      console.error('Error handling WebRTC ICE candidate:', error);
    }
  });
  
  socket.on('webrtc_end_call', async (data) => {
    try {
      const { targetUserId, groupId } = data;
      console.log(`WebRTC end call from ${socket.id} to user ${targetUserId} in group ${groupId}`);
      
      // Forward end call to target user
      socket.to(`user_${targetUserId}`).emit('webrtc_end_call', {
        fromUserId: data.fromUserId,
        groupId: groupId
      });
    } catch (error) {
      console.error('Error handling WebRTC end call:', error);
    }
  });
  
  socket.on('join_user_room', async (data) => {
    try {
      const { userId } = data;
      
      // Join user-specific room for direct communication
      socket.join(`user_${userId}`);
      console.log(`🔌 User ${socket.id} joined user room for user ${userId}`);
    } catch (error) {
      console.error('❌ Error joining user room:', error);
    }
  });
  
  socket.on('join_group_room', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Join group-specific room for group communication
      socket.join(`group_${groupId}`);
      console.log(`👥 User ${socket.id} joined group room for group ${groupId}`);
    } catch (error) {
      console.error('❌ Error joining group room:', error);
    }
  });
  
  socket.on('join_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Join voice chat room
      socket.join(`voice_chat_${groupId}`);
      console.log(`🎤 User ${socket.id} joined voice chat room for group ${groupId}`);
    } catch (error) {
      console.error('❌ Error joining voice chat room:', error);
    }
  });
  
  socket.on('leave_group_voice_chat', async (data) => {
    try {
      const { userId, groupId } = data;
      
      // Leave voice chat room
      socket.leave(`voice_chat_${groupId}`);
      console.log(`🎤 User ${socket.id} left voice chat room for group ${groupId}`);
    } catch (error) {
      console.error('❌ Error leaving voice chat room:', error);
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Etwas ist schiefgelaufen!',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Interner Serverfehler'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint nicht gefunden' });
});

const PORT = process.env.PORT || 3000;

// Start server
const startServer = async () => {
  try {
    await connectDB();
    server.listen(PORT, () => {
      const protocol = httpsOptions ? 'https' : 'http';
      console.log(`🚗 WalkiCar Backend läuft auf ${protocol}://localhost:${PORT}`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV}`);
      if (httpsOptions) {
        console.log('🔒 HTTPS aktiviert');
      } else {
        console.log('⚠️  HTTP verwendet (SSL-Zertifikate nicht gefunden)');
      }
    });
  } catch (error) {
    console.error('Fehler beim Starten des Servers:', error);
    process.exit(1);
  }
};

startServer();

module.exports = { app, io };
