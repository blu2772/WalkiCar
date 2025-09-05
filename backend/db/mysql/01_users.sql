-- Users Tabelle
CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  apple_sub VARCHAR(255) UNIQUE NOT NULL,
  display_name VARCHAR(100) NOT NULL,
  avatar_url VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_apple_sub (apple_sub),
  INDEX idx_display_name (display_name)
);
