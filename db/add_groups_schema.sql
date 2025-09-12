-- WalkiCar Groups und Voice Chat Schema - Sichere Updates
-- Füge Gruppen-Tabellen hinzu nur wenn sie nicht existieren

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
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_admin BOOLEAN DEFAULT FALSE,
    
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_group_user (group_id, user_id),
    INDEX idx_group (group_id),
    INDEX idx_user (user_id),
    INDEX idx_joined (joined_at)
);

-- Erstelle voice_sessions Tabelle nur wenn sie nicht existiert
CREATE TABLE IF NOT EXISTS voice_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    group_id INT NOT NULL,
    user_id INT NOT NULL,
    session_type VARCHAR(50) DEFAULT 'group',
    is_active BOOLEAN DEFAULT FALSE,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_group (group_id),
    INDEX idx_user (user_id),
    INDEX idx_active (is_active),
    INDEX idx_started (started_at)
);

-- Erstelle voice_participants Tabelle nur wenn sie nicht existiert
CREATE TABLE IF NOT EXISTS voice_participants (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id INT NOT NULL,
    user_id INT NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    FOREIGN KEY (session_id) REFERENCES voice_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_session (session_id),
    INDEX idx_user (user_id),
    INDEX idx_active (is_active),
    INDEX idx_joined (joined_at)
);

-- Zeige alle Tabellen nach dem Update
SHOW TABLES;

-- Zeige Struktur der neuen Tabellen
DESCRIBE groups;
DESCRIBE group_members;
DESCRIBE voice_sessions;
DESCRIBE voice_participants;
