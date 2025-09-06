const jwt = require('jsonwebtoken');
const { query } = require('../config/database');

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({ error: 'Zugriffstoken erforderlich' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Überprüfe ob der Benutzer noch existiert und aktiv ist
    const user = await query(
      'SELECT id, username, email, is_active FROM users WHERE id = ? AND is_active = TRUE',
      [decoded.userId]
    );

    if (user.length === 0) {
      return res.status(401).json({ error: 'Ungültiger Token - Benutzer nicht gefunden' });
    }

    req.user = user[0];
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token abgelaufen' });
    } else if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Ungültiger Token' });
    }
    return res.status(500).json({ error: 'Token-Verifizierung fehlgeschlagen' });
  }
};

const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

const verifyToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    return null;
  }
};

module.exports = {
  authenticateToken,
  generateToken,
  verifyToken
};
