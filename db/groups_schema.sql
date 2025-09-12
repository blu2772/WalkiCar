-- WalkiCar Groups und Voice Chat Schema
-- Erstelle die fehlenden Tabellen für Gruppen und Voice Chats

-- Erstelle groups Tabelle nur wenn sie nicht existiert
CREATE TABLE IF NOT EXISTS groups (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    creator_id INT NOT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    max_members INT DEFAULT 50,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_creator (creator_id),
    INDEX idx_active (is_active),
    INDEX idx_created (created_at)
);

-- Erstelle group_members Tabelle nur wenn sie nicht existiert
CREATE TABLE IF NOT EXISTS group_members (
    id INT PRIMARY KEY AUTO_INCREMENT,
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('admin', 'member') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_group_user (group_id, user_id),
    INDEX idx_group (group_id),
    INDEX idx_user (user_id),
    INDEX idx_role (role)
);

-- Erstelle voice_sessions Tabelle nur wenn sie nicht existiert
CREATE TABLE IF NOT EXISTS voice_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    session_type ENUM('group', 'private') DEFAULT 'group',
    is_active BOOLEAN DEFAULT TRUE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_group_active (group_id, is_active),
    INDEX idx_user_active (user_id, is_active),
    INDEX idx_started (started_at)
);

-- Zeige alle Tabellen
SHOW TABLES;

-- Zeige Struktur der neuen Tabellen
DESCRIBE groups;
DESCRIBE group_members;
DESCRIBE voice_sessions;
