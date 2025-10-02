/**
 * Server Coturn Manager - Ohne Sudo-Password-Anforderung
 * Dieses Script läuft ohne sudo-Passwort und verwendet direkte Befehle
 */

const { spawn, exec } = require('child_process');

class ServerCoturnManager {
  constructor() {
    this.isRunning = false;
  }

  /**
   * Führt einen Befehl ohne sudo aus (falls bereits korrig permissions)
   */
  async executeCommand(command, args = []) {
    return new Promise((resolve, reject) => {
      console.log(`🚀 Führe aus: ${command} ${args.join(' ')}`);
      
      const process = spawn(command, args, {
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: false
      });

      let stdout = '';
      let stderr = '';

      process.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      process.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      process.on('close', (code) => {
        if (code === 0) {
          resolve({ success: true, stdout, stderr });
        } else {
          reject(new Error(`Command failed with code ${code}: ${stderr}`));
        }
      });

      process.on('error', (error) => {
        reject(error);
      });
    });
  }

  /**
   * Versucht verschiedene Wege um Coturn zu verwalten
   */
  async startCoturn() {
    try {
      console.log('🚀 Starte Coturn-Server...');
      
      // Versuche verschiedene Methoden
      const methods = [
        () => this.executeCommand('systemctl', ['start', 'coturn']),
        () => this.executeCommand('service', ['coturn', 'start']),
        () => this.executeCommand('sudo', ['systemctl', 'start', 'coturn'])
      ];

      for (const method of methods) {
        try {
          const result = await method();
          this.isRunning = true;
          console.log('✅ Coturn erfolgreich gestartet');
          
          if (result.stdout) {
            console.log('📄 Output:', result.stdout.trim());
          }
          
          return true;
        } catch (error) {
          console.log(`⚠️ Methode fehlgeschlagen: ${error.message}`);
          continue;
        }
      }
      
      throw new Error('Alle Start-Methoden fehlgeschlagen');
      
    } catch (error) {
      console.error('❌ Fehler beim Starten von Coturn:', error.message);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * Stoppt Coturn
   */
  async stopCoturn() {
    try {
      console.log('🛑 Stoppe Coturn-Server...');
      
      // Versuche verschiedene Methoden
      const methods = [
        () => this.executeCommand('systemctl', ['stop', 'coturn']),
        () => this.executeCommand('service', ['coturn', 'stop']),
        () => this.executeCommand('sudo', ['systemctl', 'stop', 'coturn']),
        () => this.executeCommand('pkill', ['turnserver'])
      ];

      for (const method of methods) {
        try {
          const result = await method();
          this.isRunning = false;
          console.log('✅ Coturn erfolgreich gestoppt');
          
          if (result.stdout) {
            console.log('📄 Output:', result.stdout.trim());
          }
          
          return true;
        } catch (error) {
          console.log(`⚠️ Stopp-Methode fehlgeschlagen: ${error.message}`);
          continue;
        }
      }
      
      throw new Error('Alle Stopp-Methoden fehlgeschlagen');
      
    } catch (error) {
      console.error('❌ Fehler beim Stoppen von Coturn:', error.message);
      return false;
    }
  }

  /**
   * Prüft Coturn-Status
   */
  async checkStatus() {
    try {
      const methods = [
        () => this.executeCommand('systemctl', ['is-active', 'coturn']),
        () => this.executeCommand('service', ['coturn', 'status']),
        () => this.executeCommand('pgrep', ['turnserver'])
      ];

      for (const method of methods) {
        try {
          const result = await method();
          
          if (result.stdout.includes('active') || result.stdout.includes('running')) {
            this.isRunning = true;
            console.log(`📡 Coturn Status: 🟢 Aktiv`);
            return true;
          } else {
            this.isRunning = false;
            console.log(`📡 Coturn Status: 🔴 Inaktiv`);
            return false;
          }
        } catch (error) {
          console.log(`⚠️ Status-Methode fehlgeschlagen: ${error.message}`);
          continue;
        }
      }
      
      throw new Error('Alle Status-Methoden fehlgeschlagen');
      
    } catch (error) {
      console.error('❌ Fehler beim Überprüfen des Coturn-Status:', error.message);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * Zeigt detaillierte Informationen ohne sudo
   */
  async getStatusInfo() {
    try {
      console.log('📊 Coturn-Status-Informationen:');
      
      // Prozess-Status
      try {
        const procResult = await this.executeCommand('ps', ['aux']);
        const coturnLines = procResult.stdout.split('\n').filter(line => 
          line.includes('turnserver') || line.includes('coturn')
        );
        
        if (coturnLines.length > 0) {
          console.log('🔍 Aktive Coturn-Prozesse:');
          coturnLines.forEach(line => console.log('  ', line));
        } else {
          console.log('ℹ️ Keine aktiven Coturn-Prozesse gefunden');
        }
      } catch (error) {
        console.log('⚠️ Konnte Prozess-Info nicht abrufen:', error.message);
      }

      // Port-Status (alternative zu netstat)
      try {
        // Versuche verschiedene Tools für Port-Analyse
        const portCommands = [
          () => this.executeCommand('ss', ['-tulpn']),
          () => this.executeCommand('lsof', ['-i', ':3478']),
          () => this.executeCommand('lsof', ['-i', ':5349']),
          () => this.executeCommand('netstat', ['-tulpn'])
        ];

        let portsFound = false;
        for (const cmd of portCommands) {
          try {
            const result = await cmd();
            const lines = result.stdout.split('\n');
            const turnPorts = lines.filter(line => 
              line.includes(':3478') || 
              line.includes(':5349') || 
              line.includes(':49152') ||
              line.includes('turnserver') ||
              line.includes('TURN')
            );
            
            if (turnPorts.length > 0) {
              console.log('🔌 TURN-Server Ports:');
              turnPorts.forEach(port => console.log('  ', port));
              portsFound = true;
              break;
            }
          } catch (error) {
            continue; // Versuche nächsten Befehl
          }
        }

        if (!portsFound) {
          console.log('⚠️ Konnte keine TURN-Ports ermitteln');
          console.log('💡 Installiere netstat oder ss für Port-Analyse');
        }
      } catch (error) {
        console.log('⚠️ Port-Analyse komplett fehlgeschlagen:', error.message);
      }

      return true;
    } catch (error) {
      console.error('❌ Fehler beim Abrufen der Status-Info:', error.message);
      return false;
    }
  }

  /**
   * Zeigt Hilfe für Server-Umgebungen
   */
  showHelp() {
    console.log('\n🚀 WalkiCar Server Coturn Manager');
    console.log('=====================================');
    console.log('Dieses Tool läuft ohne sudo-Passwort-Anforderung');
    console.log('und versucht verschiedene Methoden um Coturn zu verwalten.');
    console.log('\nVerwendung: node server-coturn-manager.js <befehl>');
    console.log('\nVerfügbare Befehle:');
    console.log('  start     - Startet Coturn (verschiedene Methoden)');
    console.log('  status    - Zeigt Coturn-Status');
    console.log('  info      - Detaillierte Status-Informationen');
    console.log('  help      - Zeigt diese Hilfe');
    console.log('\nBeispiele:');
    console.log('  node server-coturn-manager.js status');
    console.log('  node server-coturn-manager.js info');
    console.log('\n💡 Tipp: Falls sudo benötigt wird, konfiguriere NOPASSWD für systemctl');
    console.log('');
  }

  /**
   * Prüft und konfiguriert sudoers für NOPASSWD
   */
  async suggestSudoersConfig() {
    console.log('\n🔧 Sudoers-Konfiguration für Passwordlose Coturn-Verwaltung:');
    console.log('========================================================');
    console.log('Führe folgenden Befehl aus, um sudo-Passwort zu entfernen:');
    console.log('');
    console.log('sudo visudo -f /etc/sudoers.d/walkicar-coturn');
    console.log('');
    console.log('Füge folgende Zeile hinzu:');
    console.log('dein_user ALL=(ALL) NOPASSWD: /usr/bin/systemctl * coturn, /usr/bin/service coturn');
    console.log('');
    console.log('Oder allgemeiner für alle systemctl-Befehle:');
    console.log('dein_user ALL=(ALL) NOPASSWD: /usr/bin/systemctl');
    console.log('');
    console.log('Ersetze "dein_user" mit deinem tatsächlichen Username');
    console.log('');
  }
}

// CLI-Interface
async function main() {
  const manager = new ServerCoturnManager();
  const command = process.argv[2];

  // Signal-Handler für sauberes Beleben beim Beenden des Programms
  process.on('SIGINT', () => {
    console.log('\n⚡ Programm beendet durch Benutzer');
    process.exit(0);
  });

  try {
    switch (command) {
      case 'start':
        await manager.startCoturn();
        process.exit(0);
        break;
        
      case 'stop':
        await manager.stopCoturn();
        process.exit(0);
        break;
        
      case 'status':
        await manager.checkStatus();
        process.exit(0);
        break;
        
      case 'info':
        await manager.checkStatus();
        await manager.getStatusInfo();
        process.exit(0);
        break;
        
      case 'sudoers':
        await manager.suggestSudoersConfig();
        process.exit(0);
        break;
        
      case 'help':
      default:
        manager.showHelp();
        process.exit(0);
        break;
    }
  } catch (error) {
    console.error('❌ Unerwarteter Fehler:', error.message);
    process.exit(1);
  }
}

// Nur ausführen wenn direkt aufgerufen
if (require.main === module) {
  main();
}

module.exports = ServerCoturnManager;
