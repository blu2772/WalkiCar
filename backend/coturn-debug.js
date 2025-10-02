/**
 * Coturn Debug Tool - Erweiterte Diagnose für Voice Chat Probleme
 * 
 * Dieses Tool hilft bei der Diagnose von WebRTC/Voice Chat Problemen
 */

const { spawn, exec } = require('child_process');

class CoturnDebugger {
  constructor() {
    this.serverDomain = 'walkcar.timrmp.de'; // Ersetze mit deiner Domain
    this.turnPorts = [3478, 5349];
    this.recommendedConfigured = true;
  }

  /**
   * Hilfsfunktion für sicher ausgeführtes Promise
   */
  async safeExecute(command, args = []) {
    return new Promise((resolve) => {
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
        resolve({ success: code === 0, stdout, stderr, code });
      });
    });
  }

  /**
   * Prüft Coturn-Service Status
   */
  async checkCoturnService() {
    console.log('\n🔍 === COTURN SERVICE STATUS ===');
    
    try {
      const result = await this.safeExecute('systemctl', ['status', 'coturn', '--no-pager']);
      
      if (result.success) {
        console.log('✅ Coturn Service Status:');
        console.log(result.stdout);
      } else {
        console.log('❌ Fehler beim Abrufen des Service-Status:');
        console.log(result.stderr);
      }
      
      return result.success;
    } catch (error) {
      console.log('❌ Service-Check fehlgeschlagen:', error.message);
      return false;
    }
  }

  /**
   * Prüft Coturn-Prozesse
   */
  async checkCoturnProcesses() {
    console.log('\n🔍 === COTURN PROCESSES ===');
    
    try {
      const result = await this.safeExecute('ps', ['aux']);
      
      if (result.success) {
        const lines = result.stdout.split('\n');
        const coturnLines = lines.filter(line => 
          line.includes('turnserver') || 
          line.includes('coturn')
        );
        
        if (coturnLines.length > 0) {
          console.log('✅ Aktive Coturn-Prozesse:');
          coturnLines.forEach(line => console.log('  ', line.trim()));
        } else {
          console.log('❌ Keine Coturn-Prozesse gefunden');
        }
        
        return coturnLines.length > 0;
      } else {
        console.log('❌ Fehler beim Abrufen der Prozessliste');
        return false;
      }
    } catch (error) {
      console.log('❌ Prozess-Check fehlgeschlagen:', error.message);
      return false;
    }
  }

  /**
   * Prüft Coturn-Ports
   */
  async checkCoturnPorts() {
    console.log('\n🔍 === COTURN PORTS ===');
    
    const methods = [
      () => this.safeExecute('ss', ['-tulnp']),
      () => this.safeExecute('lsof', ['-i', 'TCP:3478-65535']),
      () => this.safeExecute('netstat', ['-tulnp'])
    ];

    let portsFound = false;

    for (const method of methods) {
      try {
        const result = await method();
        
        if (result.success) {
          const lines = result.stdout.split('\n');
          const turnPorts = lines.filter(line => 
            line.includes(':3478') || 
            line.includes(':5349') ||
            line.includes('turnserver') ||
            line.includes('TURN')
          );
          
          if (turnPorts.length > 0) {
            console.log('✅ Coturn-Ports aktiv:');
            turnPorts.forEach(port => console.log('  ', port.trim()));
            portsFound = true;
            break;
          }
        }
      } catch (error) {
        console.log(`⚠️ Port-Methode fehlgeschlagen: ${error.message}`);
        continue;
      }
    }

    if (!portsFound) {
      console.log('❌ Keine Coturn-Ports gefunden');
      console.log('💡 Möglicherweise läuft Coturn nicht ordnungsgemäß');
    }

    return portsFound;
  }

  /**
   * Prüft Coturn-Konfiguration
   */
  async checkCoturnConfig() {
    console.log('\n🔍 === COTURN CONFIGURATION ===');
    
    try {
      // Prüfe ob Konfigurationsdatei existiert
      const configResult = await this.safeExecute('test', ['-f', '/etc/turnserver.conf']);
      
      if (!configResult.success) {
        console.log('❌ Coturn-Konfigurationsdatei nicht gefunden: /etc/turnserver.conf');
        return false;
      }

      console.log('✅ Konfigurations datei existiert: /etc/turnserver.conf');

      // Versuche wichtige Konfiguration anzuzeigen
      const catResult = await this.safeExecute('cat', ['/etc/turnserver.conf']);
      
      if (catResult.success) {
        const configLines = catResult.stdout.split('\n');
        
        console.log('📋 Aktueller Coturn-Konfiguration (alle relevanten Zeilen):');
        console.log('----------------------------------------');
        
        configLines.forEach(line => {
          const trimmedLine = line.trim();
          if (trimmedLine && 
              !trimmedLine.startsWith('#') && 
              (trimmedLine.includes('listening-port') || 
               trimmedLine.includes('tls-listening-port') ||
               trimmedLine.includes('relay-port') ||
               trimmedLine.includes('listening-ip') ||
               trimmedLine.includes('external-ip') ||
               trimmedLine.includes('user') ||
               trimmedLine.includes('realm') ||
               trimmedLine.includes('no-auth') ||
               trimmedLine.includes('no-cli') ||
               trimmedLine.includes('no-tls') ||
               trimmedLine.includes('no-dtls'))) {
            console.log(`  ${trimmedLine}`);
          }
        });
        console.log('----------------------------------------');
        
        return true;
      } else {
        console.log('❌ Konnte Konfiguration nicht lesen');
        return false;
      }
    } catch (error) {
      console.log('❌ Config-Check fehlgeschlagen:', error.message);
      return false;
    }
  }

  /**
   * Testet Coturn-Verbindung mit verschiedenen Tools
   */
  async testCoturnConnection() {
    console.log('\n🔍 === COTURN CONNECTION TEST ===');
    
    try {
      // Test mit telnet oder nc
      console.log('📡 Teste Verbindung zu TURN-Server...');
      
      const telnetTest = await this.safeExecute('timeout', ['5', 'telnet', 'localhost', '3478']);
      
      if (telnetTest.success) {
        console.log('✅ Telnet zu Port 3478 erfolgreich');
      } else {
        console.log('❌ Telnet zu Port 3478 fehlgeschlagen');
        
        // Versuche nc (netcat)
        const ncTest = await this.safeExecute('timeout', ['3', 'nc', '-zv', 'localhost', '3478']);
        if (ncTest.success) {
          console.log('✅ nc-Test zu Port 3478 erfolgreich');
        } else {
          console.log('❌ nc-Test zu Port 3478 fehlgeschlagen');
        }
      }
      
    } catch (error) {
      console.log('⚠️ Verbindungstest fehlgeschlagen:', error.message);
    }
  }

  /**
   * Zeigt empfohlene ICE-Server-Konfiguration für iOS-App
   */
  showRecommendedConfig() {
    console.log('\n📱 === EMPFOHLENE iOS-APP KONFIGURATION ===');
    console.log('Für deine iOS-App benötigst du diese ICE-Server-Konfiguration:');
    console.log('');
    console.log('SWIFT-KODE für iOS-App:');
    console.log(`
let iceServers = [
    RTCIceServer(
        urls: ["turn:${this.serverDomain}:3478"],
        username: "DEIN_USERNAME",  // Aus /etc/turnserver.conf
        credential: "DEIN_PASSWORD"  // Aus /etc/turnserver.conf
    ),
    RTCIceServer(
        urls: ["turns:${this.serverDomain}:5349"],
        username: "DEIN_USERNAME",
        credential: "DEIN_PASSWORD"
    ),
    RTCIceServer(
        urls: ["stun:${this.serverDomain}:3478"]
    ),
    RTCIceServer(
        urls: ["stun:stun.l.google.com:19302"]
    )
]
    `);
    console.log('');
    console.log('🔧 Wichtige Punkte:');
    console.log('1. Ersetze DEIN_USERNAME und DEIN_PASSWORD mit echten Werten');
    console.log('2. Stelle sicher dass die Domäne auf deine IP zeigt');
    console.log('3. Prüfe dass Port 3478 und 5349 offen sind');
    console.log('4. Verwende sowohl UDP (turn:) als auch TLS (turns:)');
  }

  /**
   * Vollständige Diagnose
   */
  async runFullDiagnosis() {
    console.log('🚀 === COTURN VOICE CHAT DIAGNOSE ===');
    console.log(`Server: ${this.serverDomain}`);
    console.log(`Zeit: ${new Date().toISOString()}`);
    
    const results = {
      service: await this.checkCoturnService(),
      processes: await this.checkCoturnProcesses(),
      ports: await this.checkCoturnPorts(),
      config: await this.checkCoturnConfig(),
      connection: await this.testCoturnConnection()
    };

    console.log('\n📊 === DIAGNOSE ZUSAMMENFASSUNG ===');
    console.log(`Coturn Service: ${results.service ? '✅ OK' : '❌ PROBLEM'}`);
    console.log(`Coturn Prozesse: ${results.processes ? '✅ OK' : '❌ PROBLEM'}`);
    console.log(`Coturn Ports: ${results.ports ? '✅ OK' : '❌ PROBLEM'}`);
    console.log(`Coturn Config: ${results.config ? '✅ OK' : '❌ PROBLEM'}`);
    console.log(`Coturn Connection: ${results.connection ? '✅ OK' : '❌ PROBLEM'}`);

    const allGood = Object.values(results).every(r => r);
    
    if (allGood) {
      console.log('\n🎉 ALLE TESTS BESTANDEN!');
      console.log('💡 Das Problem liegt wahrscheinlich in der iOS-App Konfiguration');
      this.showRecommendedConfig();
    } else {
      console.log('\n⚠️ PROBLEME GEFUNDEN!');
      console.log('💡 Definiere folgende Schritte:');
      
      if (!results.service) {
        console.log('  1. Systemctl-Probleme: sudo systemctl restart coturn');
      }
      if (!results.processes) {
        console.log('  2. Prozess-Probleme: sudo systemctl start coturn');
      }
      if (!results.ports) {
        console.log('  3. Port-Probleme: Prüfe Firewall und Coturn-Konfiguration');
      }
      if (!results.config) {
        console.log('  4. Config-Probleme: sudo nano /etc/turnserver.conf');
      }
    }

    return results;
  }
}

// CLI-Interface
async function main() {
  const debugger = new CoturnDebugger();
  const command = process.argv[2] || 'full';

  try {
    switch (command) {
      case 'full':
        await debugger.runFullDiagnosis();
        break;
      case 'service':
        await debugger.checkCoturnService();
        break;
      case 'processes':
        await debugger.checkCoturnProcesses();
        break;
      case 'ports':
        await debugger.checkCoturnPorts();
        break;
      case 'config':
        await debugger.checkCoturnConfig();
        break;
      case 'connection':
        await debugger.testCoturnConnection();
        break;
      case 'ios-config':
        debugger.showRecommendedConfig();
        break;
      case 'help':
      default:
        console.log('\n🚀 Coturn Debug Tool');
        console.log('====================');
        console.log('Verwendung: node coturn-debug.js <befehl>');
        console.log('\nVerfügbare Befehle:');
        console.log('  full          - Vollständige Diagnose');
        console.log('  service       - Nur Service-Status');
        console.log('  processes     - Nur Prozess-Check');
        console.log('  ports         - Nur Port-Check');
        console.log('  config         - Nur Config-Check');
        console.log('  connection     - Nur Verbindungstest');
        console.log('  ios-config     - Zeigt iOS-Konfiguration');
        console.log('  help           - Diese Hilfe');
        break;
    }
    process.exit(0);
  } catch (error) {
    console.error('❌ Fehler:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = CoturnDebugger;
