const express = require('express');
const router = express.Router();

// Platzhalter für Gruppen-Routen
router.get('/list', (req, res) => {
  res.json({ message: 'Gruppen-Routen werden implementiert' });
});

module.exports = router;
