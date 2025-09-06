# WalkiCar Datenbank Setup

Diese Anleitung hilft dir dabei, die MySQL-Datenbank für die WalkiCar App einzurichten.

## 🗄️ Datenbank-Schema

Das Schema befindet sich in `walkicar_schema.sql` und enthält alle notwendigen Tabellen für:

- **Benutzerverwaltung** (users, user_sessions)
- **Freundesystem** (friendships, notifications)
- **Fahrzeugverwaltung** (cars, location_settings)
- **Gruppen und Voice-Chats** (groups, group_members, voice_sessions)
- **Standortfreigabe** (locations)

## 🚀 Schnellstart

### 1. MySQL installieren (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install mysql-server
sudo mysql_secure_installation
```

### 2. Datenbank und Benutzer erstellen
```bash
# Als root-Benutzer anmelden
sudo mysql -u root -p

# Datenbank erstellen
CREATE DATABASE walkicar_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Benutzer erstellen
CREATE USER 'walkicar_user'@'localhost' IDENTIFIED BY 'your_secure_password';

# Berechtigungen vergeben
GRANT ALL PRIVILEGES ON walkicar_db.* TO 'walkicar_user'@'localhost';
FLUSH PRIVILEGES;

# Beenden
EXIT;
```

### 3. Schema importieren
```bash
mysql -u walkicar_user -p walkicar_db < walkicar_schema.sql
```

### 4. Verbindung testen
```bash
mysql -u walkicar_user -p walkicar_db -e "SHOW TABLES;"
```

## 🔧 Konfiguration

### Backend .env Datei
```env
DB_HOST=localhost
DB_PORT=3306
DB_NAME=walkicar_db
DB_USER=walkicar_user
DB_PASSWORD=your_secure_password
```

## 📊 Tabellen-Übersicht

| Tabelle | Zweck | Wichtige Felder |
|---------|-------|-----------------|
| `users` | Benutzerdaten | apple_id, email, username, is_online |
| `friendships` | Freundschaftsbeziehungen | user_id, friend_id, status |
| `cars` | Fahrzeugdaten | user_id, name, brand, model, bluetooth_identifier |
| `groups` | Gruppen für Voice-Chats | name, creator_id, is_public |
| `locations` | Standortdaten | user_id, car_id, latitude, longitude |
| `notifications` | Benachrichtigungen | user_id, type, title, message |

## 🔍 Indizes und Performance

Das Schema enthält optimierte Indizes für:
- Schnelle Benutzersuche (apple_id, email, username)
- Effiziente Freundschaftsabfragen
- Standort-basierte Queries
- Online-Status-Updates

## 🧪 Test-Daten

Das Schema enthält initiale Test-Daten:
- 2 Test-Benutzer
- 2 Test-Fahrzeuge
- Beispiel-Standorteinstellungen

## 🔒 Sicherheit

- **Fremdschlüssel-Constraints** für Datenintegrität
- **CASCADE-Löschungen** für konsistente Daten
- **UNIQUE-Constraints** für eindeutige Beziehungen
- **Zeitstempel-Trigger** für automatische Updates

## 📈 Monitoring

### Wichtige Queries für Monitoring:

```sql
-- Online-Benutzer zählen
SELECT COUNT(*) FROM users WHERE is_online = TRUE;

-- Aktive Freundschaften
SELECT COUNT(*) FROM friendships WHERE status = 'accepted';

-- Registrierungen heute
SELECT COUNT(*) FROM users WHERE DATE(created_at) = CURDATE();

-- Durchschnittliche Fahrzeuge pro Benutzer
SELECT AVG(car_count) FROM (
    SELECT user_id, COUNT(*) as car_count 
    FROM cars GROUP BY user_id
) as user_cars;
```

## 🚨 Backup

### Automatisches Backup einrichten:
```bash
# Backup-Script erstellen
cat > backup_walkicar.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u walkicar_user -p walkicar_db > backup_walkicar_$DATE.sql
gzip backup_walkicar_$DATE.sql
EOF

chmod +x backup_walkicar.sh

# Cron-Job für tägliche Backups
echo "0 2 * * * /path/to/backup_walkicar.sh" | crontab -
```

## 🔄 Wartung

### Regelmäßige Wartungsaufgaben:

```sql
-- Alte Sessions bereinigen
DELETE FROM user_sessions WHERE expires_at < NOW();

-- Alte Standortdaten bereinigen (älter als 30 Tage)
DELETE FROM locations WHERE timestamp < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Tabellen optimieren
OPTIMIZE TABLE users, friendships, cars, locations;
```

## 🆘 Troubleshooting

### Häufige Probleme:

1. **Verbindungsfehler:**
   ```bash
   # Firewall prüfen
   sudo ufw status
   sudo ufw allow 3306
   ```

2. **Berechtigungsfehler:**
   ```sql
   SHOW GRANTS FOR 'walkicar_user'@'localhost';
   ```

3. **Zeichensatz-Probleme:**
   ```sql
   ALTER DATABASE walkicar_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

## 📞 Support

Bei Problemen mit der Datenbank:
1. Prüfe die MySQL-Logs: `/var/log/mysql/error.log`
2. Teste die Verbindung: `mysql -u walkicar_user -p walkicar_db`
3. Überprüfe die Berechtigungen: `SHOW GRANTS FOR 'walkicar_user'@'localhost';`
