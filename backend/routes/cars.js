const express = require('express');
const router = express.Router();

// Platzhalter für Fahrzeug-Routen
router.get('/garage', (req, res) => {
  res.json({ message: 'Fahrzeug-Garage-Routen werden implementiert' });
});

module.exports = router;
