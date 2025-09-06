const express = require('express');
const router = express.Router();

// Platzhalter für Benutzer-Routen
router.get('/profile', (req, res) => {
  res.json({ message: 'Benutzerprofil-Routen werden implementiert' });
});

module.exports = router;
