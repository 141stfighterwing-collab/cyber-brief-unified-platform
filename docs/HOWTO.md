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
- [Endpoint Agent Deployment](#endpoint-agent-deployment)
  - [Windows Agent Installation](#windows-agent-installation)
  - [Modular Agent Structure](#modular-agent-structure)
  - [Company-Specific Signatures](#company-specific-signatures)
  - [Downloading Signed EXE from Company Portal](#downloading-signed-exe-from-company-portal)
  - [Linux Agent Installation](#linux-agent-installation)
  - [Docker Agent Deployment](#docker-agent-deployment)
  - [Multi-Tenant Agent Deployment](#multi-tenant-agent-deployment)
  - [Agent Troubleshooting](#agent-troubleshooting)
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

## Endpoint Agent Deployment

CBUP includes lightweight endpoint monitoring agents for Windows and Linux. These agents collect system telemetry, perform EDR (Endpoint Detection and Response) scans, and report back to the CBUP server in real time. Agent version **2.1.0** introduces a modular architecture (15 PowerShell modules), company-specific code signing for EXE downloads, and 7 bug fixes across EDR scanning, telemetry, and password validation. See the [CHANGELOG](CHANGELOG.md) for full details.

### Windows Agent Installation

The Windows agent is built in PowerShell and supports Windows 10, Windows 11, Windows Server 2016, 2019, and 2022. It requires PowerShell 5.1 or later. There are three installation methods available depending on your environment and security requirements.

#### Method 1: PowerShell One-Liner (Recommended)

The fastest way to deploy the Windows agent is via a PowerShell one-liner. This downloads the agent script, configures the server URL and registration token, and starts the agent service in a single command. Run this in an elevated PowerShell prompt (Run as Administrator):

```powershell
# Replace with your CBUP server URL and tenant token
$ServerUrl = "https://cbup.yourcompany.com"
$Token = "your-tenant-registration-token"

# Download and execute the agent installer
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression "(Invoke-RestMethod -Uri '$ServerUrl/api/agent/windows/install.ps1?token=$Token')"
```

This command will:
1. Download the latest `install-agent.ps1` script from your CBUP server
2. Validate the PowerShell version (5.1+)
3. Create the agent directory at `C:\Program Files\CBUP\Agent`
4. Install the agent as a Windows service (`CBUPAgent`)
5. Configure automatic startup via the Windows Service Control Manager
6. Register the agent with your tenant using the provided token
7. Start the telemetry collection and EDR scanning loop

#### Method 2: Manual Download

For air-gapped environments or when direct download from the server is not possible, you can manually download the agent files and configure them:

```powershell
# 1. Create the agent directory
New-Item -ItemType Directory -Force -Path "C:\Program Files\CBUP\Agent"

# 2. Download the agent script (or copy from removable media)
Invoke-WebRequest -Uri "https://cbup.yourcompany.com/api/agent/windows/cbup-agent.ps1" `
  -OutFile "C:\Program Files\CBUP\Agent\cbup-agent.ps1"

# 3. Download the service installer
Invoke-WebRequest -Uri "https://cbup.yourcompany.com/api/agent/windows/install-service.ps1" `
  -OutFile "C:\Program Files\CBUP\Agent\install-service.ps1"

# 4. Configure the agent
@"
CBUP_SERVER_URL=https://cbup.yourcompany.com
CBUP_TOKEN=your-tenant-registration-token
CBUP_INTERVAL=300
CBUP_LOG_LEVEL=info
"@ | Set-Content -Path "C:\Program Files\CBUP\Agent\.env"

# 5. Install and start the service
Set-ExecutionPolicy Bypass -Scope Process -Force
cd "C:\Program Files\CBUP\Agent"
.\install-service.ps1
```

#### Method 3: EXE Build with Company Signature (ps2exe)

For environments where PowerShell scripts are restricted or you need a standalone executable, the agent can be compiled into a company-signed `.exe` file using `ps2exe`. The signed build embeds a tenant-specific SHA256 fingerprint for integrity verification. This is particularly useful for deploying via Group Policy Objects (GPO) or configuration management tools like SCCM:

```powershell
# 1. Install ps2exe module
Install-Module -Name ps2exe -Scope CurrentUser -Force

# 2. Download the build script from your company portal (includes signature)
Invoke-WebRequest -Uri "https://cbup.yourcompany.com/api/agents/install-script?platform=windows-exe&token=TENANT_TOKEN" `
  -OutFile "C:\Program Files\CBUP\Agent\build-exe.ps1"

# 3. Build the signed EXE
.
build-exe.ps1

# 4. Install the EXE as a Windows service
sc.exe create CBUPAgent binPath= "C:\Program Files\CBUP\Agent\dist\CBUP-Agent.exe" start= auto DisplayName= "CBUP Endpoint Agent"
sc.exe description CBUPAgent "Cyber Brief Unified Platform - Endpoint Monitoring Agent v2.1.0"
sc.exe start CBUPAgent
```

The signature is automatically embedded during the build process and verified at agent startup. See [Company-Specific Signatures](#company-specific-signatures) for details.

#### System Tray Application

On Windows 10 and Windows 11 desktop editions, the agent includes an optional system tray application that provides visual status indicators and quick access to agent configuration. The tray app shows a green icon when all checks pass, yellow when there are warnings, and red when the agent cannot reach the CBUP server:

```powershell
# Launch the system tray application (after agent installation)
Start-Process "C:\Program Files\CBUP\Agent\cbup-tray.ps1"

# To auto-start the tray app for all users (via registry)
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" `
  -Name "CBUPAgentTray" `
  -Value "C:\Program Files\CBUP\Agent\cbup-tray.ps1" `
  -PropertyType String `
  -Force
```

#### Service Management Commands

Use these commands to manage the Windows agent service from an elevated PowerShell or Command Prompt:

```powershell
# Check service status
Get-Service -Name CBUPAgent

# Start the service
Start-Service -Name CBUPAgent

# Stop the service
Stop-Service -Name CBUPAgent

# Restart the service
Restart-Service -Name CBUPAgent

# Disable automatic startup
Set-Service -Name CBUPAgent -StartupType Manual

# Enable automatic startup
Set-Service -Name CBUPAgent -StartupType Automatic

# Uninstall the service completely
sc.exe delete CBUPAgent
```

#### Verification Steps

After installing the Windows agent, verify it is working correctly:

```powershell
# 1. Confirm the service is running
Get-Service -Name CBUPAgent | Select-Object Status, StartType
# Expected: Status=Running, StartType=Automatic

# 2. Check the agent log file
Get-Content "C:\Program Files\CBUP\Agent\logs\agent.log" -Tail 20

# 3. Verify the agent registered with the server
Invoke-RestMethod -Uri "https://cbup.yourcompany.com/api/agent/status" `
  -Headers @{ Authorization = "Bearer your-tenant-registration-token" }

# 4. Check Windows Event Log for agent entries
Get-WinEvent -LogName "CBUP-Agent" -MaxEvents 10

# 5. Test connectivity to the CBUP server
Test-NetConnection -ComputerName cbup.yourcompany.com -Port 443
```

### Modular Agent Structure

Starting with v2.1.0, the Windows PowerShell agent uses a modular architecture. Instead of a single 2,296-line script, the agent is composed of **15 focused modules** loaded via dot-sourcing from a lightweight 336-line entry point (`CBUP-Agent.ps1`).

#### Module Directory Structure

```
C:\Program Files\CBUP\Agent\
├── CBUP-Agent.ps1              # Entry point (336 lines)
├── CBUP-Agent-Tray.ps1         # Optional system tray app
├── modules\
│   ├── CBUP-Logging.ps1        # Timestamped log output
│   ├── CBUP-Registry.ps1       # Registry read/write helpers
│   ├── CBUP-API.ps1            # HTTP communication + retry
│   ├── CBUP-Discovery.ps1      # System discovery data
│   ├── CBUP-Telemetry.ps1      # Real-time metrics
│   ├── CBUP-EDR-Process.ps1    # Process analysis scan
│   ├── CBUP-EDR-Service.ps1    # Service enumeration scan
│   ├── CBUP-EDR-Port.ps1       # Port scanning
│   ├── CBUP-EDR-Autorun.ps1    # Persistence detection scan
│   ├── CBUP-EDR-Vulnerability.ps1 # Vulnerability assessment
│   ├── CBUP-EDR-Full.ps1       # Full scan orchestrator
│   ├── CBUP-C2Commands.ps1     # C2 command handler
│   ├── CBUP-Service.ps1        # Windows service management
│   ├── CBUP-Registration.ps1   # Agent registration
│   └── CBUP-Signature.ps1      # Company signature system
```

#### How It Works

1. The entry point (`CBUP-Agent.ps1`) defines global variables and configuration
2. It dot-sources each module in dependency order: Logging → Registry → API → Discovery → etc.
3. Each module exports functions into the global scope
4. The main loop calls functions from the loaded modules for telemetry, EDR scans, and C2

#### Benefits

- **Maintainability**: Each module is under 450 lines — easy to review and modify independently
- **Testing**: Individual modules can be tested in isolation using PowerShell's `-NoProfile` mode
- **Selective Loading**: You can comment out unused modules to reduce the agent's memory footprint
- **Security**: The signature module operates independently and validates the agent before any telemetry is sent

#### Loading a Module Manually (for testing)

```powershell
# Test a single module in isolation
$ModulePath = "C:\Program Files\CBUP\Agent\modules"
. "$ModulePath\CBUP-Logging.ps1"
. "$ModulePath\CBUP-Discovery.ps1"

# Call a function from the module
$data = Get-SystemDiscoveryData
$data | ConvertTo-Json -Depth 5
```

### Company-Specific Signatures

v2.1.0 introduces a per-company cryptographic signature system for Windows EXE builds. This ensures that each company's agent binary is uniquely identifiable and tamper-evident.

#### How It Works

1. **Signature Generation**: When you download the `build-exe.ps1` from your company portal, it includes your tenant token
2. **Fingerprint Creation**: The `CBUP-Signature.ps1` module generates a SHA256 hash from the tenant token and stores it in the Windows registry
3. **EXE Embedding**: During the build process, the signature is embedded into the compiled EXE's metadata
4. **Runtime Verification**: On startup, the agent reads the embedded signature and compares it against the registry-stored fingerprint
5. **Tamper Detection**: If the signatures don't match, the agent logs a security warning and refuses to start

#### Signature Registry Location

```
HKLM:\SOFTWARE\CBUP\Signature
    CompanyId    = "acme-corp"
    Fingerprint  = "a1b2c3d4e5f6..."  (SHA256 hash)
    SignedAt     = "2026-04-03T12:00:00Z"
    SignedBy     = "CBUP Agent Build Script v2.1.0"
```

#### Verifying a Signature

```powershell
# Check the stored signature
Get-ItemProperty -Path "HKLM:\SOFTWARE\CBUP\Signature" | Format-List

# Verify the EXE signature matches
& "C:\Program Files\CBUP\Agent\modules\CBUP-Signature.ps1"
Test-AgentSignature -Path "C:\Program Files\CBUP\Agent\dist\CBUP-Agent.exe"

# Expected output: SignatureValid = True
```

#### Rotating a Signature

If you need to re-sign an agent (e.g., after a security audit or token rotation):

1. Rotate the tenant token in the CBUP admin panel
2. Re-download `build-exe.ps1` from the portal (it will include the new token)
3. Rebuild the EXE: `.\build-exe.ps1`
4. Redeploy the new EXE to all endpoints

### Downloading Signed EXE from Company Portal

Each tenant's admin portal provides a pre-configured download URL that includes the company signature. The process is fully automated:

#### Step-by-Step

1. **Log into your CBUP admin portal** at `https://your-cbup-server.com`
2. **Navigate to Agents → Deploy New Agent**
3. **Select the "Windows EXE" tab**
4. **Click "Download Build Script"** — this downloads `build-exe.ps1` with your tenant token pre-embedded
5. **Run the build script on a trusted Windows machine**:
   ```powershell
   .\build-exe.ps1
   ```
6. **Distribute the signed EXE** (`dist/CBUP-Agent.exe`) to target endpoints

#### Direct API Download

You can also download the build script directly via the API:

```powershell
# Download with your tenant token
Invoke-WebRequest -Uri "https://YOUR-PORTAL/api/agents/install-script?platform=windows-exe&token=TENANT_TOKEN" `
  -OutFile "build-exe.ps1"

# Build the signed EXE
.
build-exe.ps1

# The signed EXE is at: .\dist\CBUP-Agent.exe
```

#### Verification After Download

```powershell
# Verify the build script includes your company's token
Select-String -Path "build-exe.ps1" -Pattern "TENANT_TOKEN"

# After building, verify the EXE exists
Test-Path ".\dist\CBUP-Agent.exe"
# Expected: True

# Verify the signature was embedded
Get-ItemProperty -Path "HKLM:\SOFTWARE\CBUP\Signature" -ErrorAction SilentlyContinue
```

### Linux Agent Installation

The Linux agent supports Ubuntu 20.04/22.04/24.04, Linux Mint 21.x/22.x, Debian 11+, and CentOS/RHEL 8+. It runs as a systemd service and integrates with the system's native logging infrastructure.

#### Method 1: curl One-Liner (Recommended)

The fastest deployment method is a single curl command that downloads and runs the installer. Run this with `sudo` privileges:

```bash
# Replace with your CBUP server URL and tenant token
CBUP_SERVER_URL="https://cbup.yourcompany.com" \
CBUP_TOKEN="your-tenant-registration-token" \
bash <(curl -sSL "${CBUP_SERVER_URL}/api/agent/linux/install.sh?token=${CBUP_TOKEN}")
```

This command will:
1. Detect the Linux distribution and version
2. Install any required dependencies (curl, gzip, openssl)
3. Create the agent directory at `/opt/cbup-agent`
4. Download the `cbup-agent.sh` script
5. Create the `.env` configuration file with your server URL and token
6. Install a systemd service (`cbup-agent.service`)
7. Enable and start the service
8. Verify connectivity to the CBUP server

#### Method 2: Manual Download

For air-gapped environments or custom deployment pipelines:

```bash
# 1. Create the agent directory
sudo mkdir -p /opt/cbup-agent/logs

# 2. Download the agent script (or copy from removable media)
sudo curl -sSL -o /opt/cbup-agent/cbup-agent.sh \
  https://cbup.yourcompany.com/api/agent/linux/cbup-agent.sh
sudo chmod +x /opt/cbup-agent/cbup-agent.sh

# 3. Create the configuration file
sudo tee /opt/cbup-agent/.env << EOF
CBUP_SERVER_URL=https://cbup.yourcompany.com
CBUP_TOKEN=your-tenant-registration-token
CBUP_INTERVAL=300
CBUP_LOG_LEVEL=info
CBUP_EDR_SCAN=true
EOF

# 4. Protect the config (contains token)
sudo chmod 600 /opt/cbup-agent/.env

# 5. Install the systemd service
sudo tee /etc/systemd/system/cbup-agent.service << SVC
[Unit]
Description=CBUP Endpoint Agent v2.1.0
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash /opt/cbup-agent/cbup-agent.sh
Restart=always
RestartSec=10
EnvironmentFile=/opt/cbup-agent/.env

[Install]
WantedBy=multi-user.target
SVC

# 6. Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable cbup-agent
sudo systemctl start cbup-agent
```

#### Systemd Service Management

Manage the Linux agent using standard systemd commands:

```bash
# Check service status
sudo systemctl status cbup-agent

# Start the service
sudo systemctl start cbup-agent

# Stop the service
sudo systemctl stop cbup-agent

# Restart the service
sudo systemctl restart cbup-agent

# View live logs
sudo journalctl -u cbup-agent -f

# View last 100 log lines
sudo journalctl -u cbup-agent -n 100 --no-pager

# Disable automatic startup
sudo systemctl disable cbup-agent

# Uninstall the service completely
sudo systemctl stop cbup-agent
sudo systemctl disable cbup-agent
sudo rm /etc/systemd/system/cbup-agent.service
sudo systemctl daemon-reload
sudo rm -rf /opt/cbup-agent
```

#### Verification Steps

After installing the Linux agent, confirm it is operating correctly:

```bash
# 1. Confirm the service is running
sudo systemctl is-active cbup-agent
# Expected: active

# 2. Check recent logs
sudo journalctl -u cbup-agent -n 20 --no-pager

# 3. Verify the agent registered with the server
curl -s -H "Authorization: Bearer your-tenant-registration-token" \
  https://cbup.yourcompany.com/api/agent/status | jq .

# 4. Test connectivity to the CBUP server
curl -s -o /dev/null -w "%{http_code}" https://cbup.yourcompany.com/api/health
# Expected: 200

# 5. Verify the agent process is running
ps aux | grep cbup-agent | grep -v grep

# 6. Check the agent configuration
sudo cat /opt/cbup-agent/.env
```

### Docker Agent Deployment

The CBUP agent can also run as a Docker container, which is useful for containerized environments, CI/CD pipelines, or situations where you prefer not to install software directly on the host. The Docker agent image includes the full Linux agent with all EDR scanning capabilities.

#### Docker Run Command

The simplest way to deploy the agent in Docker is a single `docker run` command:

```bash
# Pull and run the agent container
docker run -d \
  --name cbup-agent \
  --restart unless-stopped \
  -e CBUP_SERVER_URL="https://cbup.yourcompany.com" \
  -e CBUP_TOKEN="your-tenant-registration-token" \
  -e CBUP_INTERVAL=300 \
  -e CBUP_LOG_LEVEL=info \
  -e CBUP_EDR_SCAN=true \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v cbup-agent-data:/data \
  -v /var/log:/host-log:ro \
  cbup/agent:2.1.0

# Check container status
docker ps --filter name=cbup-agent

# View agent logs
docker logs -f cbup-agent

# Stop the agent
docker stop cbup-agent && docker rm cbup-agent
```

The container mounts the host's Docker socket (read-only) for container discovery, the host log directory for log analysis, and a named volume for persistent agent state data.

#### Docker Compose Configuration

For more complex deployments or when running alongside other services, use Docker Compose:

```yaml
# docker-compose.yml
version: "3.8"
services:
  cbup-agent:
    image: cbup/agent:2.1.0
    container_name: cbup-agent
    restart: unless-stopped
    environment:
      - CBUP_SERVER_URL=https://cbup.yourcompany.com
      - CBUP_TOKEN=your-tenant-registration-token
      - CBUP_INTERVAL=300
      - CBUP_LOG_LEVEL=info
      - CBUP_EDR_SCAN=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - cbup-agent-data:/data
      - /var/log:/host-log:ro
    networks:
      - cbup-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 30s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  cbup-agent-data:
    driver: local

networks:
  cbup-net:
    external: false
```

```bash
# Start the agent
 docker compose up -d

# View logs
 docker compose logs -f cbup-agent

# Restart the agent
 docker compose restart cbup-agent

# Stop and remove
 docker compose down
```

#### Environment Variable Configuration

The Docker agent is configured entirely through environment variables. The following table lists all supported options:

| Variable | Required | Default | Description |
|----------|:--------:|---------|-------------|
| `CBUP_SERVER_URL` | Yes | — | Full URL of the CBUP server |
| `CBUP_TOKEN` | Yes | — | Tenant registration token |
| `CBUP_INTERVAL` | No | `300` | Telemetry reporting interval in seconds |
| `CBUP_LOG_LEVEL` | No | `info` | Log verbosity: `debug`, `info`, `warn`, `error` |
| `CBUP_EDR_SCAN` | No | `true` | Enable/disable EDR scanning |
| `CBUP_TLS_VERIFY` | No | `true` | Enable/disable TLS certificate verification |
| `CBUP_HOSTNAME_OVERRIDE` | No | — | Override the reported hostname |
| `CBUP_TAGS` | No | — | Comma-separated tags for agent grouping |

#### Volume and Network Setup

The Docker agent uses several volume mounts for full functionality:

- **`/var/run/docker.sock`** (read-only): Required for Docker container discovery. Mounting this as read-only is a security best practice — the agent only needs to list containers and inspect their state.
- **`/var/log`** (read-only): Provides access to host system logs for analysis. This allows the agent to parse syslog, auth logs, and application logs for security events.
- **Named volume `cbup-agent-data`**: Stores the agent's persistent state, including registration data, scan history, and cached results. This volume survives container restarts and updates.

For network setup, the agent only needs outbound HTTPS access (port 443) to your CBUP server. No inbound ports are required. You can restrict the container's network access further:

```bash
# Restrict to a specific network with outbound-only access
docker network create --internal --driver bridge cbup-isolated
docker network connect --alias cbup-agent cbup-isolated
```

### Multi-Tenant Agent Deployment

CBUP supports multi-tenant deployments where each company or organization operates as a separate tenant with its own agents, data, and access controls. This section explains how tenant-specific tokens work and how to deploy agents for multiple organizations.

#### How Tenant-Specific Tokens Work

Each tenant in CBUP receives a unique registration token during account creation. When an agent registers with the server, it presents this token, and the server automatically assigns the agent to the correct tenant. This means:

- Agents from different tenants cannot see each other's data
- The server isolates all telemetry, EDR results, and configurations per tenant
- Tenant administrators can only manage their own agents
- Agents inherit the tenant's scanning policies and reporting intervals

Tokens are long-lived by default but can be rotated from the CBUP admin panel. When a token is rotated, existing agents will need to be updated with the new token to continue reporting.

#### Download URLs per Company Portal

Each tenant has a unique agent download URL that embeds their registration token. This allows you to distribute installation instructions to end users without exposing the raw token. Users simply visit their company-specific portal to get the correct installation commands:

```bash
# Company portal URLs follow this pattern:
# https://cbup.yourcompany.com/portal/<company-slug>/agent

# Example: Acme Corp's agent download page
# https://cbup.yourcompany.com/portal/acme-corp/agent

# The portal page generates platform-specific install commands:
# Windows: PowerShell one-liner with token embedded
# Linux:   curl one-liner with token embedded
# Docker:  docker run command with token as environment variable
```

#### Agent Assignment to Tenants

When deploying agents across multiple tenants, follow these guidelines:

```bash
# 1. Retrieve the token for each tenant from the admin panel
# Or via the API:
curl -s -H "Authorization: Bearer admin-api-key" \
  https://cbup.yourcompany.com/api/admin/tenants | jq '.[].name, .[].agentToken'

# 2. Deploy agents per-tenant using their specific tokens
# For tenant "acme-corp":
CBUP_TOKEN="acme-corp-token-abc123" bash <(curl -sSL "https://cbup.yourcompany.com/api/agent/linux/install.sh")

# For tenant "globex-inc":
CBUP_TOKEN="globex-inc-token-xyz789" bash <(curl -sSL "https://cbup.yourcompany.com/api/agent/linux/install.sh")

# 3. Verify agents are assigned to the correct tenants
curl -s -H "Authorization: Bearer admin-api-key" \
  https://cbup.yourcompany.com/api/admin/agents | jq '.[] | {hostname, tenant, status}'
```

For bulk deployments, you can script the agent installation across multiple hosts using Ansible, Chef, or a simple shell loop. Ensure each host receives the correct tenant token, and consider using the `CBUP_TAGS` environment variable to label agents by department, location, or role:

```bash
# Example: Deploy to 10 Linux servers with department tags
for host in server-01 server-02 server-03 server-04 server-05 \
            server-06 server-07 server-08 server-09 server-10; do
  ssh "$host" "CBUP_SERVER_URL=https://cbup.yourcompany.com \
    CBUP_TOKEN=acme-corp-token-abc123 \
    CBUP_TAGS=production,datacenter-east \
    bash <(curl -sSL https://cbup.yourcompany.com/api/agent/linux/install.sh)"
done
```

### Agent Troubleshooting

This section covers common issues encountered when deploying and running CBUP endpoint agents across Windows and Linux platforms.

#### Agent Won't Register

If the agent fails to register with the CBUP server, the most common cause is an invalid or expired token. Verify the token is correct and that the agent can reach the server:

```bash
# Linux — Test server connectivity
curl -v https://cbup.yourcompany.com/api/health

# Linux — Verify the token is set correctly
cat /opt/cbup-agent/.env | grep CBUP_TOKEN

# Linux — Check registration logs
sudo journalctl -u cbup-agent --since "10 minutes ago" | grep -i "register\|token\|auth"
```

```powershell
# Windows — Test server connectivity
Test-NetConnection -ComputerName cbup.yourcompany.com -Port 443

# Windows — Verify the token in config
Get-Content "C:\Program Files\CBUP\Agent\.env" | Select-String "CBUP_TOKEN"

# Windows — Check event log for registration errors
Get-WinEvent -LogName "CBUP-Agent" -MaxEvents 20 | Where-Object { $_.Message -match "register|token|auth" }
```

**Common causes**: Expired token, corporate firewall blocking HTTPS to the CBUP server, DNS resolution failure, proxy configuration not set. If behind a proxy, configure it via `HTTPS_PROXY` in the agent's `.env` file.

#### Telemetry Not Reporting

When the agent is registered but telemetry data is not appearing on the CBUP dashboard:

```bash
# Linux — Check if the agent process is running
sudo systemctl status cbup-agent

# Linux — Look for telemetry-related log entries
sudo journalctl -u cbup-agent --since "1 hour ago" | grep -i "telemetry\|report\|send"

# Linux — Manually trigger a telemetry report
/opt/cbup-agent/cbup-agent.sh --report-now

# Linux — Check the reporting interval
sudo cat /opt/cbup-agent/.env | grep CBUP_INTERVAL
```

```powershell
# Windows — Check if the service is running
Get-Service -Name CBUPAgent

# Windows — Manually trigger a report
& "C:\Program Files\CBUP\Agent\cbup-agent.ps1" -ReportNow

# Windows — Check the agent log for errors
Get-Content "C:\Program Files\CBUP\Agent\logs\agent.log" -Tail 50 | Select-String "telemetry|report|error"
```

**Common causes**: Reporting interval set too high (check `CBUP_INTERVAL`), agent process crashed silently, server under heavy load and rejecting reports, network connectivity lost after initial registration.

#### EDR Scan Failures

EDR scans may fail due to permission issues or missing tools on the endpoint:

```bash
# Linux — Run a manual EDR scan to see detailed errors
sudo /opt/cbup-agent/cbup-agent.sh --edr-scan --verbose

# Linux — Check if required tools are available
which ss netstat ps lsof

# Linux — Verify the agent has permission to read /proc
ls -la /proc/self/status
```

```powershell
# Windows — Run a manual EDR scan
& "C:\Program Files\CBUP\Agent\cbup-agent.ps1" -EdrScan -Verbose

# Windows — Verify PowerShell can access WMI and registry
Get-WmiObject Win32_Process | Select-Object -First 5
Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run

# Windows — Check if ps2exe-compiled agent has admin rights
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

**Common causes**: Agent not running with sufficient privileges (run as root/Administrator), SELinux blocking access on Linux, Windows Defender or other AV blocking the agent from reading certain registry keys or processes.

#### Service Won't Start (Windows)

If the CBUP Windows service fails to start:

```powershell
# Check the service status and error code
Get-Service -Name CBUPAgent
sc.exe query CBUPAgent

# Check the Windows System event log for service errors
Get-WinEvent -LogName "System" -MaxEvents 20 | Where-Object { $_.ProviderName -eq "Service Control Manager" -and $_.Message -match "CBUPAgent" }

# Verify the executable/script path is correct
sc.exe qc CBUPAgent

# Check if PowerShell execution policy is blocking the script
Get-ExecutionPolicy
Get-ExecutionPolicy -Scope Machine

# If execution policy is restrictive, set it for the service
Set-ExecutionPolicy RemoteSigned -Scope Machine -Force

# Reinstall the service if the path has changed
sc.exe delete CBUPAgent
& "C:\Program Files\CBUP\Agent\install-service.ps1"
```

**Common causes**: Service executable path contains spaces and is unquoted, PowerShell execution policy blocking script execution, missing .NET Framework dependency, service account lacks permissions to access the agent directory.

#### Systemd Failures (Linux)

If the `cbup-agent` systemd service fails to start or crashes repeatedly:

```bash
# Check the service status with full details
sudo systemctl status cbup-agent

# View the full journal log for the service
sudo journalctl -u cbup-agent -n 100 --no-pager

# Check if the service file syntax is valid
sudo systemd-analyze verify /etc/systemd/system/cbup-agent.service

# Verify the agent script is executable
ls -la /opt/cbup-agent/cbup-agent.sh

# If permissions are wrong, fix them
sudo chmod +x /opt/cbup-agent/cbup-agent.sh
sudo chmod 600 /opt/cbup-agent/.env

# Check if the environment file is readable by the service
sudo -u root cat /opt/cbup-agent/.env

# Reload systemd if you changed the service file
sudo systemctl daemon-reload
sudo systemctl restart cbup-agent

# If SELinux is blocking the agent (check audit log)
sudo ausearch -m avc -ts recent | grep cbup-agent
# If SELinux is the issue, create a permissive policy
sudo grep cbup-agent /var/log/audit/audit.log | audit2allow -M cbup-agent-policy
sudo semodule -i cbup-agent-policy.pp
```

**Common causes**: Agent script not marked as executable (missing `chmod +x`), environment file has incorrect permissions, SELinux blocking file access on RHEL/CentOS, service file has a typo in the `ExecStart` path, agent script has a syntax error from a failed update.

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
