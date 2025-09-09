{
  "name": "walkicar-backend",
  "script": "server.js",
  "instances": 1,
  "exec_mode": "fork",
  "env": {
    "NODE_ENV": "production",
    "PORT": 3000
  },
  "log_file": "/var/log/walkicar.log",
  "out_file": "/var/log/walkicar-out.log",
  "error_file": "/var/log/walkicar-error.log",
  "log_date_format": "YYYY-MM-DD HH:mm:ss Z",
  "merge_logs": true,
  "max_memory_restart": "1G",
  "restart_delay": 4000,
  "max_restarts": 10,
  "min_uptime": "10s"
}
