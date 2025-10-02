const { spawn } = require('child_process');

/**
 * CoturnManager - Verwaltet Coturn-Server automatisch
 * 
 * Verwendung:
 * node coturn-manager.js start    // Startet Coturn
 * node coturn-manager.js stop     // Stoppt Coturn  
 * node coturn-manager.js status   // Zeigt Status
 * node coturn-manager.js restart  // Neustart Coturn
 */

class CoturnManager {
  constructor() {
    this.isRunning = false;
    this.statusCheckInterval = null;
  }

  /**
   * Erstellt eine geführte sudo-Ausführung
   */
  async executeSudo(command, args = []) {
    return new Promise((resolve, reject) => {
      console.log(`🚀 Führe aus: sudo ${command} ${args.join(' ')}`);
      
      const process = spawn('sudo', [command, ...args], {
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
   * Startet Coturn-Server
   */
  async startCoturn() {
    try {
      if (this.isRunning) {
        console.log('📡 Coturn läuft bereits');
        return true;
      }

      console.log('🚀 Starte Coturn-Server...');
      
      const result = await this.executeSudo('systemctl', ['start', 'coturn']);
      
      this.isRunning = true;
      console.log('✅ Coturn erfolgreich gestartet');
      
      if (result.stdout) {
        console.log('📄 Output:', result.stdout.trim());
      }
      
      return true;
    } catch (error) {
      console.error('❌ Fehler beim Starten von Coturn:', error.message);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * Stoppt Coturn-Server
   */
  async stopCoturn() {
    try {
      if (!this.isRunning) {
        console.log('📡 Coturn läuft nicht');
        return true;
      }

      console.log('🛑 Stoppe Coturn-Server...');
      
      const result = await this.executeSudo('systemctl', ['stop', 'coturn']);
      
      this.isRunning = false;
      console.log('✅ Coturn erfolgreich gestoppt');
      
      if (result.stdout) {
        console.log('📄 Output:', result.stdout.trim());
      }
      
      return true;
    } catch (error) {
      console.error('❌ Fehler beim Stoppen von Coturn:', error.message);
      return false;
    }
  }

  /**
   * Überprüft Status von Coturn
   */
  async checkStatus() {
    try {
      const result = await this.executeSudo('systemctl', ['is-active', 'coturn']);
      
      this.isRunning = result.stdout.trim() === 'active';
      
      console.log(`📡 Coturn Status: ${this.isRunning ? '🟢 Aktiv' : '🔴 Inaktiv'}`);
      
      return this.isRunning;
    } catch (error) {
      console.error('❌ Fehler beim Überprüfen des Coturn-Status:', error.message);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * Startet Coturn neu
   */
  async restartCoturn() {
    try {
      console.log('🔄 Starte Coturn neu...');
      
      const result = await this.executeSudo('systemctl', ['restart', 'coturn']);
      
      this.isRunning = true;
      console.log('✅ Coturn erfolgreich neugestartet');
      
      // Kurz warten und Status prüfen
      setTimeout(async () => {
        await this.checkStatus();
      }, 2000);
      
      return true;
    } catch (error) {
      console.error('❌ Fehler beim Neustarten von Coturn:', error.message);
      this.isRunning = false;
      return false;
    }
  }

  /**
   * Zeigt detaillierte Status-Informationen
   */
  async getDetailedStatus() {
    try {
      console.log('📊 Detaillierte Coturn-Status-Informationen:');
      
      // Status
      const statusResult = await this.executeSudo('systemctl', ['status', 'coturn']);
      console.log('📄 Status:', statusResult.stdout);
      
      // Journal-Logs (letzte 10 Zeilen)
      const logResult = await this.executeSudo('journalctl', ['-u', 'coturn', '-n', '10', '--no-pager']);
      console.log('📝 Letzte Logs:', logResult.stdout);
      
      return true;
    } catch (error) {
      console.error('❌ Fehler beim Abrufen detaillierter Status:', error.message);
      return false;
    }
  }

  /**
   * Überwacht Coturn kontinuierlich
   */
  startMonitoring(intervalMs = 30000) {
    console.log(`🔍 Starte Coturn-Überwachung (Intervall: ${intervalMs}ms)...`);
    
    this.statusCheckInterval = setInterval(async () => {
      const wasRunning = this.isRunning;
      await this.checkStatus();
      
      if (wasRunning && !this.isRunning) {
        console.warn('⚠️ Coturn ist unerwartet gestoppt!');
      } else if (!wasRunning && this.isRunning) {
        console.log('✅ Coturn ist wieder aktiv!');
      }
    }, intervalMs);
  }

  /**
   * Stoppt die Überwachung
   */
  stopMonitoring() {
    if (this.statusCheckInterval) {
      clearInterval(this.statusCheckInterval);
      this.statusCheckInterval = null;
      console.log('🛑 Coturn-Überwachung gestoppt');
    }
  }

  /**
   * Zeigt verfügbare Befehle
   */
  showHelp() {
    console.log('\n🚀 WalkiCar Coturn Manager');
    console.log('============================');
    console.log('Verwendung: node coturn-manager.js <befehl>');
    console.log('\nVerfügbare Befehle:');
    console.log('  start     - Startet Coturn-Server');
    console.log('  stop      - Stoppt Coturn-Server');
    console.log('  restart   - Startet Coturn neu');
    console.log('  status    - Zeigt aktuellen Status');
    console.log('  details   - Zeigt detaillierte Status-Informationen');
    console.log('  monitor   - Startet kontinuierliche Überwachung');
    console.log('  help      - Zeigt diese Hilfe');
    console.log('\nBeispiele:');
    console.log('  npm run manage:coturn start');
    console.log('  npm run manage:coturn status'); 
    console.log('  npm run manage:coturn monitor');
    console.log('');
  }
}

// CLI-Interface
async function main() {
  const manager = new CoturnManager();
  const command = process.argv[2];

  // Signal-Handler für sauberes Beleben beim Beenden des Programms
  process.on('SIGINT', () => {
    console.log('\n⚡ Programm beendet durch Benutzer');
    manager.stopMonitoring();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\n⚡ Programm beendet durch Signal');
    manager.stopMonitoring();
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
        
      case 'restart':
        await manager.restartCoturn();
        process.exit(0);
        break;
        
      case 'status':
        await manager.checkStatus();
        process.exit(0);
        break;
        
      case 'details':
        await manager.getDetailedStatus();
        process.exit(0);
        break;
        
      case 'monitor':
        await manager.startMonitoring();
        console.log('💡 Drücke Ctrl+C zum Beenden der Überwachung');
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

module.exports = CoturnManager;
