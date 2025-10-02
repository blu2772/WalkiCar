module.exports = {
  apps: [{
    name: 'walkicar-backend',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_file: '/var/log/walkicar.log',
    out_file: '/var/log/walkicar-out.log',
    error_file: '/var/log/walkicar-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    // Coturn-Hooks für automatischen Start/Stop
    pre_start: 'sudo systemctl start coturn',
    post_stop: 'sudo systemctl stop coturn'
  }, {
    name: 'coturn-monitor',
    script: 'coturn-monitor.js',
    instances: 1,
    autorestart: false,
    watch: false,
    interrupt_timeout: 5000,
    kill_timeout: 5000
  }]
};
