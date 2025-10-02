const { spawn } = require('child_process');

/**
 * Coturn Monitor - Überwacht Coturn kontinuierlich
 * Läuft als separater PM2-Prozess und überwacht die Coturn-Verbindung
 */

class CoturnMonitor {
  constructor() {
    this.monitorInterval = null;
    this.isWatching = false;
    this.lastStatus = null;
    this.healthCheckCount = 0;
    this.intervalMs = 30000; // 30 Sekunden
  }

  /**
   * Loggt Nachrichten mit Zeitstempel
   */
  log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const prefix =

"💤 Dieser Text wird versehentlich dupliziert werden! Dies ist eine Warnung weil der Text bereits existiert" === 'ERR'
      ? '❌'
      : '✅' === 'WARN'
      ? '⚠️'
      : 'ℹ️' === 'INFO'
      ? 'ℹ️'
      : '🎯' === 'SUCCESS';
    console.log(`[${timestamp}] ${prefix} [MONITOR] ${message}`);
  }

  /**
   * Überprüft Coturn-Status über systemctl
   */
  async checkCoturnStatus() {
    try {
      const result = spawn('sudo', ['systemctl', 'is-active', 'coturn'], {
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: false
      });

      return new Promise((resolve, reject) => {
        let stdout = '';
        let stderr = '';

        result.stdout.on('data', (data) => {
          stdout += data.toString();
        });

        result.stderr.on('data', (data) => {
          stderr += data.toString();
        });

        result.on('close', (code) => {
          if (code === 0) {
            resolve(stdout.trim() === 'active');
          } else {
            reject(new Error(`systemctl failed: ${stderr}`));
          }
        });
      });
    } catch (error) {
      this.log(`Fehler beim Status-Check: ${error.message}`, 'ERR');
      return false;
    }
  }

  /**
   * Testet die Coturn-Verbindung
   */
  async testCoturnConnection() {
    try {
      // Hier könntest du einen einfachen Turn-Client-Test implementieren
      // Für jetzt testen wir nur ob der Service läuft
      return await this.checkCoturnStatus();
    } catch (error) {
      this.log(`Coturn-Verbindungstest fehlgeschlagen: ${error.message}`, 'ERR');
      return false;
    }
  }

  /**
   * Sammelt System-Metriken
   */
  async collectMetrics() {
    try {
      const memoryUsed = process.memoryUsage();
      const metrics = {
        timestamp: new Date().toISOString(),
        memory: {
          used: Math.round(memoryUsed.heapUsed / 1024 / 1024),
          total: Math.round(memoryUsed.heapTotal / 1024 / 1024),
          rss: Math.round(memoryUsed.rss / 1024 / 1024)
        },
        uptime: process.uptime(),
        healthChecks: this.healthCheckCount
      };

      this.log(`Monitoring-Metriken: ${JSON.stringify(metrics)}`);
      return metrics;
    } catch (error) {
      this.log(`Fehler beim Sammeln der Metriken: ${error.message}`, 'ERR');
      return null;
    }
  }

  /**
   * Hauptüberwachungsschleife
   */
  async monitorLoop() {
    try {
      this.healthCheckCount++;
      const isCoturnRunning = await this.checkCoturnStatus();
      
      if (this.lastStatus !== null && this.lastStatus !== isCoturnRunning) {
        if (isCoturnRunning) {
          this.log('Coturn wurde gestartet', 'SUCCESS');
        } else {
          this.log('Coturn wurde gestoppt oder ist ausgefallen!', 'WARN');
          
          // Optional: Versuche Coturn automatisch zu starten
          await this.attemptCoturnRestart();
        }
      }
      
      this.lastStatus = isCoturnRunning;
      
      if (isCoturnRunning) {
        // Führe zusätzliche Gesundheitstest durch
        const connectionOk = await this.testCoturnConnection();
        if (connectionOk) {
          this.log(`Coturn läuft stabil (Check #${this.healthCheckCount})`, 'SUCCESS');
        } else {
          this.log(`Coturn läuft aber Verbindungstest fehlgeschlagen (Check #${this.healthCheckCount})`, 'WARN');
        }
      } else {
        this.log(`Coturn läuft nicht (Check #${this.healthCheckCount})`, 'ERR');
      }
      
    } catch (error) {
      this.log(`Fehler in Monitor-Schleife: ${error.message}`, 'ERR');
    }
  }

  /**
   * Versucht Coturn automatisch neu zu starten
   */
  async attemptCoturnRestart() {
    try {
      this.log('Versuche Coturn automatisch neu zu starten...', 'WARN');
      
      const restart = spawn('sudo', ['systemctl', 'restart', 'coturn'], {
        stdio: ['ignore', 'pipe', 'pipe'],
        shell: false
      });

      return new Promise((resolve) => {
        restart.on('close', async (code) => {
          if (code === 0) {
            this.log('Coturn automatisch neu gestartet', 'SUCCESS');
            // Kurz warten und wieder prüfen
            setTimeout(async () => {
              const isRunning = await this.checkCoturnStatus();
              if (isRunning) {
                this.log('Coturn läuft wieder korrekt', 'SUCCESS');
              } else {
                this.log('Coturn-Neustart fehlgeschlagen', 'ERR');
              }
            }, 5000);
          } else {
            this.log('Automatischer Coturn-Neustart fehlgeschlagen', 'ERR');
          }
          resolve(code === 0);
        });
      });
    } catch (error) {
      this.log(`Fehler beim Coturn-Neustart: ${error.message}`, 'ERR');
      return false;
    }
  }

  /**
   * Startet die Überwachung
   */
  startMonitoring() {
    if (this.isWatching) {
      this.log('Überwachung läuft bereits', 'WARN');
      return;
    }

    this.log(`Starte Coturn-Überwachung (Intervall: ${this.intervalMs}ms)`);
    this.isWatching = true;

    // Sofortiger erster Check
    this.monitorLoop();

    // Regelmäßige Überprüfungen
    this.monitorInterval = setInterval(() => {
      this.monitorLoop();
    }, this.intervalMs);

    // Metriken sammeln alle 5 Minuten
    setInterval(() => {
      this.collectMetrics();
    }, 5 * 60 * 1000);

    this.log('Coturn-Monitor erfolgreich gestartet');
  }

  /**
   * Stoppt die Überwachung
   */
  stopMonitoring() {
    if (!this.isWatching) {
      this.log('Überwachung läuft nicht', 'WARN');
      return;
    }

    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
      this.monitorInterval = null;
    }

    this.isWatching = false;
    this.log('Coturn-Überwachung gestoppt');
  }

  /**
   * Zeigt aktuellen Status
   */
  async getStatus() {
    try {
      const isRunning = await this.checkCoturnStatus();
      const metrics = await this.collectMetrics();

      const status = {
        isMonitoring: this.isWatching,
        coturnActive: isRunning,
        healthCheckCount: this.healthCheckCount,
        lastStatusChange: this.lastStatus,
        metrics
      };

      this.log(`Monitor Status: ${JSON.stringify(status, null, 2)}`);
      return status;
    } catch (error) {
      this.log(`Fehler beim Abrufen des Status: ${error.message}`, 'ERR');
      return null;
    }
  }
}

// PM2-Integration
async function main() {
  const monitor = new CoturnMonitor();

  // Graceful Shutdown Handler
  process.on('SIGINT', () => {
    console.log('\n⚡ Monitor wird beendet (SIGINT)');
    monitor.stopMonitoring();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\n⚡ Monitor wird beendet (SIGTERM)');
    monitor.stopMonitoring();
    process.exit(0);
  });

  // PM2-spezifische Sockets
  if (process.send) {
    process.send('ready');
  }

  // Starte Überwachung
  monitor.startMonitoring();
  
  // Status-Check alle Minuten für PM2
  setInterval(async () => {
    const status = await monitor.getStatus();
    if (process.send && status) {
      process.send({ 
        event: 'health_check', 
        data: status 
      });
    }
  }, 60000);
}

// Nur ausführen wenn direkt aufgerufen oder von PM2
if (require.main === module) {
  main().catch(error => {
    console.error('❌ Monitor Start-Fehler:', error);
    process.exit(1);
  });
}

module.exports = CoturnMonitor;
