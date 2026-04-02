# How-To Guides

## Table of Contents

- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Bare Metal Installation](#bare-metal-installation)
  - [Docker Installation](#docker-installation)
  - [Development Setup](#development-setup)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Custom Port](#custom-port)
  - [Domain & SSL Setup](#domain--ssl-setup)
  - [Reverse Proxy with Caddy](#reverse-proxy-with-caddy)
  - [Reverse Proxy with Nginx](#reverse-proxy-with-nginx)
- [Daily Operations](#daily-operations)
  - [Checking Status](#checking-status)
  - [Viewing Logs](#viewing-logs)
  - [Creating Backups](#creating-backups)
  - [Restoring from Backup](#restoring-from-backup)
  - [Updating CBUP](#updating-cbup)
- [User Management](#user-management)
  - [Creating Users](#creating-users)
  - [Changing Tiers](#changing-tiers)
  - [Resetting Passwords](#resetting-passwords)
- [Security Hardening](#security-hardening)
  - [Firewall Rules](#firewall-rules)
  - [File Permissions](#file-permissions)
  - [SSL/TLS Termination](#ssltls-termination)
  - [Network Isolation](#network-isolation)
- [Troubleshooting](#troubleshooting)
  - [Service Won't Start](#service-wont-start)
  - [Database Errors](#database-errors)
  - [Port Already in Use](#port-already-in-use)
  - [Out of Memory](#out-of-memory)
  - [Update Failed](#update-failed)

---

## Installation

### Prerequisites

| Requirement | Minimum Version | Check Command |
|-------------|----------------|---------------|
| Operating System | Ubuntu 20.04 / Debian 11 / CentOS 8 / RHEL 8 | `cat /etc/os-release` |
| Architecture | x86_64 or ARM64 | `uname -m` |
| Disk Space | 5 GB free | `df -h` |
| RAM | 2 GB minimum (4 GB recommended) | `free -m` |
| Root Access | Required for installation | `sudo whoami` |

### Bare Metal Installation

#### Method 1: 1-Click Script (Recommended)

```bash
# Download and run the installer
curl -sSL https://raw.githubusercontent.com/141stfighterwing-collab/cyber-brief-unified-platform/main/install.sh | sudo bash
```

Or if you have the repo cloned locally:

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer will:
1. Detect your OS and architecture
2. Install system prerequisites (curl, git, build tools)
3. Install the Bun runtime
4. Set up application files in `/opt/cbup`
5. Install Node.js dependencies
6. Initialize the SQLite database
7. Build the Next.js production bundle
8. Create a systemd service (`cbup.service`)
9. Configure firewall rules
10. Start the service
11. Install the `cbup` management CLI

#### Method 2: Manual Installation

```bash
# 1. Install Bun
curl -fsSL https://bun.sh/install | bash

# 2. Clone the repository
sudo git clone https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git /opt/cbup
sudo chown -R $(whoami):$(whoami) /opt/cbup

# 3. Install dependencies
cd /opt/cbup
bun install

# 4. Set up database
mkdir -p /var/lib/cbup
export DATABASE_URL="file:/var/lib/cbup/cbup.db"
bun run db:push

# 5. Create .env file
cat > .env << 'EOF'
DATABASE_URL="file:/var/lib/cbup/cbup.db"
NODE_ENV=production
PORT=3000
EOF

# 6. Build for production
bun run build

# 7. Create systemd service
sudo cat > /etc/systemd/system/cbup.service << SVC
[Unit]
Description=Cyber Brief Unified Platform
After=network-online.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/opt/cbup
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DATABASE_URL=file:/var/lib/cbup/cbup.db
ExecStart=$(which bun) run start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

# 8. Start the service
sudo systemctl daemon-reload
sudo systemctl enable cbup
sudo systemctl start cbup
```

### Docker Installation

#### Method 1: Using the Installer

```bash
sudo ./install.sh --docker
```

#### Method 2: Manual Docker

```bash
# Clone the repo
git clone https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

# Build the image
docker build -t cbup .

# Run the container
docker run -d \
  --name cyber-brief-up \
  --restart unless-stopped \
  -p 3000:3000 \
  -v cbup-data:/app/data \
  -v cbup-logs:/app/logs \
  -e DATABASE_URL="file:/app/data/cbup.db" \
  -e NODE_ENV=production \
  cbup

# Check status
docker ps | grep cyber-brief-up
docker logs -f cyber-brief-up
```

#### Docker Compose

```bash
# Save this as docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  cbup:
    build: .
    container_name: cyber-brief-up
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - cbup-data:/app/data
    environment:
      - DATABASE_URL=file:/app/data/cbup.db
      - NODE_ENV=production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

volumes:
  cbup-data:
    driver: local
EOF

# Start
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

# Install dependencies
bun install

# Generate Prisma client
bun run db:generate

# Set up database
bun run db:push

# Start development server (hot-reload enabled)
bun run dev
```

The dev server runs at `http://localhost:3000` and automatically reloads when you save changes.

---

## Configuration

### Environment Variables

All configuration is done via environment variables. Create or edit `/opt/cbup/.env`:

```env
# ─── Database ────────────────────────────────
DATABASE_URL="file:/var/lib/cbup/cbup.db"

# ─── Application ─────────────────────────────
NODE_ENV=production          # "development" | "production"
PORT=3000                    # Application port (default: 3000)

# ─── Authentication (Future) ─────────────────
# NEXTAUTH_SECRET="your-random-secret-here"
# NEXTAUTH_URL="http://your-domain.com"
```

After changing environment variables, restart the service:

```bash
sudo systemctl restart cbup
# or
cbup restart
```

### Custom Port

#### During Installation

```bash
sudo ./install.sh --port 8080
```

#### After Installation

1. Edit `/etc/systemd/system/cbup.service` and change the port:
   ```ini
   Environment=PORT=8080
   ```
2. Edit `/opt/cbup/.env`:
   ```env
   PORT=8080
   ```
3. Reload and restart:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart cbup
   ```

### Domain & SSL Setup

#### Option 1: Caddy (Automatic HTTPS)

Caddy automatically provisions and renews SSL certificates via Let's Encrypt. A Caddyfile is included in the project root.

```bash
# Install Caddy
sudo apt install -y caddy   # Debian/Ubuntu
sudo dnf install -y caddy   # RHEL/CentOS

# Configure Caddy
sudo tee /etc/caddy/Caddyfile << EOF
your-domain.com {
    reverse_proxy localhost:3000
}
EOF

# Restart Caddy
sudo systemctl restart caddy
```

CBUP will now be accessible at `https://your-domain.com` with automatic SSL.

#### Option 2: Nginx + Certbot

```bash
# Install Nginx and Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Configure Nginx
sudo tee /etc/nginx/sites-available/cbup << EOF
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the site
sudo ln -s /etc/nginx/sites-available/cbup /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Provision SSL certificate
sudo certbot --nginx -d your-domain.com
```

### Reverse Proxy with Caddy

The included `Caddyfile` in the project root handles:

- Automatic HTTPS with Let's Encrypt
- Request forwarding to the Next.js app on port 3000
- Header forwarding (X-Forwarded-For, X-Real-IP)
- Port transformation for internal services

### Reverse Proxy with Nginx

For Nginx configurations that need to support the internal port transformation query parameter:

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Daily Operations

### Checking Status

```bash
# Quick status check
cbup status

# Systemd service status
sudo systemctl status cbup

# Check if the port is listening
ss -tlnp | grep 3000

# HTTP health check
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
# Should return: 200
```

### Viewing Logs

```bash
# Tail the last 50 lines
cbup logs

# Tail the last 200 lines
cbup logs 200

# Follow logs live
cbup logs 0

# Using systemd journal
sudo journalctl -u cbup -f

# Using systemd journal (last 100 lines)
sudo journalctl -u cbup -n 100

# Docker logs
docker logs -f cyber-brief-up
```

### Creating Backups

```bash
# Create a timestamped, compressed backup
cbup backup
# Output: /var/backups/cbup/cbup-backup-20250115-083000.db.gz

# Set up daily automatic backups
echo "0 2 * * * /usr/local/bin/cbup backup" | sudo crontab -

# Verify backups exist
ls -lh /var/backups/cbup/
```

### Restoring from Backup

```bash
# List available backups
cbup restore

# Restore a specific backup
cbup restore /var/backups/cbup/cbup-backup-20250115-083000.db.gz

# Manual restore
sudo systemctl stop cbup
gunzip -c /var/backups/cbup/cbup-backup-20250115.db.gz > /var/lib/cbup/cbup.db
sudo systemctl start cbup
```

### Updating CBUP

```bash
# Automatic update (recommended — includes backup, pull, rebuild, restart)
cbup update

# Manual update
cd /opt/cbup
sudo git pull origin main
bun install
DATABASE_URL="file:/var/lib/cbup/cbup.db" bun run db:push
bun run build
sudo systemctl restart cbup
```

---

## User Management

### Creating Users

Users can be created through the web UI (Sign Up page) or via the API:

```bash
# Via API
curl -X POST http://localhost:3000/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@company.com",
    "company": "Acme Corp",
    "password": "SecurePassword123!",
    "tier": "starter"
  }'
```

### Changing Tiers

Tier changes can be made directly in the database:

```bash
# Using sqlite3 CLI
sqlite3 /var/lib/cbup/cbup.db "UPDATE User SET tier = 'pro' WHERE email = 'john@company.com';"

# Restart the service for changes to take effect
cbup restart
```

### Resetting Passwords

Currently, passwords can be reset via the database (full auth system coming in v1.0):

```bash
# Set a new password (must be bcrypt-hashed)
# This is a placeholder — proper password reset will be available in a future release
sqlite3 /var/lib/cbup/cbup.db "UPDATE User SET password = NULL WHERE email = 'user@example.com';"
```

---

## Security Hardening

### Firewall Rules

The installer automatically configures firewall rules. For manual setup:

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 3000/tcp
sudo ufw reload

# firewalld (RHEL/CentOS)
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload

# iptables (universal)
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

If using a reverse proxy with SSL, you may only need to open port 443:
```bash
sudo ufw allow 80/tcp    # HTTP (redirect to HTTPS)
sudo ufw allow 443/tcp   # HTTPS
```

### File Permissions

The installer sets restrictive permissions. Verify:

```bash
# Application files — owned by cbup user
ls -la /opt/cbup/
# Should show cbup:cbup ownership

# Database file — only readable by cbup user
ls -la /var/lib/cbup/cbup.db
# Should show -rw-r----- cbup cbup

# Logs — readable by cbup user
ls -la /var/log/cbup/
# Should show cbup:cbup ownership

# Service file — root owned
ls -la /etc/systemd/system/cbup.service
# Should show -rw-r--r-- root root
```

### SSL/TLS Termination

Always use HTTPS in production. See the [Domain & SSL Setup](#domain--ssl-setup) section for Caddy or Nginx + Certbot configuration.

### Network Isolation

For enhanced security, restrict CBUP to only be accessible from your internal network:

```bash
# UFW — only allow internal subnet
sudo ufw deny 3000/tcp
sudo ufw allow from 10.0.0.0/8 to any port 3000
sudo ufw allow from 172.16.0.0/12 to any port 3000
sudo ufw allow from 192.168.0.0/16 to any port 3000
```

---

## Troubleshooting

### Service Won't Start

```bash
# Check service status
sudo systemctl status cbup

# Check logs for errors
cbup logs 50

# Check systemd journal
sudo journalctl -u cbup -n 50 --no-pager

# Common causes:
# 1. Port 3000 already in use → change PORT in .env
# 2. Database locked → check for other processes using the db file
# 3. Missing dependencies → run bun install
# 4. Build artifacts missing → run bun run build
```

### Database Errors

```bash
# Check database integrity
sqlite3 /var/lib/cbup/cbup.db "PRAGMA integrity_check;"

# Check database size
du -h /var/lib/cbup/cbup.db

# If the database is corrupted, restore from backup:
cbup restore /var/backups/cbup/cbup-backup-latest.db.gz

# Or reset completely:
cbup reset-db
```

### Port Already in Use

```bash
# Check what's using port 3000
sudo lsof -i :3000
# or
sudo ss -tlnp | grep 3000

# Kill the process
sudo kill <PID>

# Or change CBUP's port
# Edit /opt/cbup/.env → PORT=8080
# Edit /etc/systemd/system/cbup.service → Environment=PORT=8080
# sudo systemctl daemon-reload && sudo systemctl restart cbup
```

### Out of Memory

```bash
# Check current memory usage
free -m

# Check CBUP process memory
ps aux | grep -E "node|bun" | grep -v grep

# Add a swap file if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Update Failed

```bash
# If cbup update fails:
# 1. Check the error message in the logs
cbup logs 50

# 2. Manually pull and rebuild
cd /opt/cbup
git stash           # Save local changes
git pull origin main
git stash pop       # Restore local changes (resolve conflicts if any)
bun install
DATABASE_URL="file:/var/lib/cbup/cbup.db" bun run db:push
bun run build
sudo systemctl restart cbup

# 3. If the build fails due to a broken dependency:
rm -rf node_modules .next
bun install
bun run build
sudo systemctl restart cbup

# 4. If everything fails, restore from backup and reinstall:
cbup restore /var/backups/cbup/cbup-backup-latest.db.gz
```
