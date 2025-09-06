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
    version: '1.0.0'
  });
});

// Socket.IO connection handling
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) {
    return next(new Error('Authentication error'));
  }
  // TODO: Verify JWT token here
  next();
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);
  
  socket.on('join_room', (roomId) => {
    socket.join(roomId);
    console.log(`User ${socket.id} joined room ${roomId}`);
  });
  
  socket.on('leave_room', (roomId) => {
    socket.leave(roomId);
    console.log(`User ${socket.id} left room ${roomId}`);
  });
  
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
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
