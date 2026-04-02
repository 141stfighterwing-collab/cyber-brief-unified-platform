#!/usr/bin/env bash
set -euo pipefail

#
# ██████╗ ██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗
# ██╔══██╗██╔═══██╗████╗  ██║██╔════╝ ██╔══██╗██╔════╝
# ██████╔╝██║   ██║██╔██╗ ██║██║  ███╗██████╔╝█████╗
# ██╔═══╝ ██║   ██║██║╚██╗██║██║   ██║██╔══██╗██╔══╝
# ██║     ╚██████╔╝██║ ╚████║╚██████╔╝██║  ██║███████╗
# ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
#
# Cyber Brief Unified Platform — 1-Click Installer
# 
# Tested on: Ubuntu 20.04/22.04/24.04, Linux Mint 21.x/22.x, Windows WSL2
# Install modes: bare-metal, docker, dev
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/141stfighterwing-collab/cyber-brief-unified-platform/main/install.sh | sudo bash
#   ./install.sh                      # Interactive install
#   ./install.sh --docker             # Docker install
#   ./install.sh --dev                # Development mode (no systemd, no root needed)
#   ./install.sh --port 8080          # Custom port
#   ./install.sh --yes                # Non-interactive
#   ./install.sh --uninstall          # Remove CBUP
#   ./install.sh --test               # Run validation tests
#

# ─── Colors ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Globals ──────────────────────────────────────────
INSTALL_DIR="/opt/cbup"
DATA_DIR="/var/lib/cbup"
LOG_DIR="/var/log/cbup"
BACKUP_DIR="/var/backups/cbup"
SERVICE_NAME="cbup"
PORT=3000
USE_DOCKER=false
DEV_MODE=false
NONINTERACTIVE=false
UNINSTALL=false
RUN_TESTS=false
BRANCH="main"
REPO_URL="https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git"

# Detected at runtime
PKG_MANAGER=""
OS_ID=""
OS_VERSION=""
OS_NAME=""
DOCKER_REPO_ID=""   # The actual ID to use for Docker repo (may differ from OS_ID)
IS_WSL=false
HAS_SYSTEMD=false

# ─── Helpers ──────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; }
step()    { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }
die()     { error "$*"; exit 1; }

separator() {
  echo -e "\n${DIM}─────────────────────────────────────────────────${NC}"
}

banner() {
  separator
  echo -e "${BOLD}${CYAN}"
  cat << 'BANNER'
   ██████╗ ██████╗ ███╗   ██╗ ██████╗ ██████╗ ███████╗
  ██╔══██╗██╔═══██╗████╗  ██║██╔════╝ ██╔══██╗██╔════╝
  ██████╔╝██║   ██║██╔██╗ ██║██║  ███╗██████╔╝█████╗
  ██╔═══╝ ██║   ██║██║╚██╗██║██║   ██║██╔══██╗██╔══╝
  ██║     ╚██████╔╝██║ ╚████║╚██████╔╝██║  ██║███████╗
  ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
BANNER
  echo -e "${NC}${DIM}  Cyber Brief Unified Platform — 1-Click Installer${NC}"
  separator
}

ask() {
  if $NONINTERACTIVE; then
    echo "$1 (default: $2) → using default"
    return 0
  fi
  read -rp "$(echo -e "${CYAN}$1${NC} (default: ${GREEN}$2${NC}): ")" val
  val="${val:-$2}"
  echo "$val"
}

ask_yes() {
  if $NONINTERACTIVE; then
    return 0
  fi
  read -rp "$(echo -e "${CYAN}$1${NC} [Y/n]: ")" val
  [[ -z "$val" || "$val" =~ ^[Yy] ]]
}

# ─── WSL Detection ───────────────────────────────────
detect_wsl() {
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    IS_WSL=true
    # Detect WSL version
    if [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
      info "Detected: Windows Subsystem for Linux (WSL)"
    else
      info "Detected: Windows Subsystem for Linux"
    fi
  fi
}

# ─── systemd Detection ───────────────────────────────
detect_systemd() {
  # Check PID 1
  if [[ "$(readlink -f /proc/1/exe 2>/dev/null)" == *systemd* ]]; then
    HAS_SYSTEMD=true
    return
  fi
  # Check if systemctl command works
  if command -v systemctl &>/dev/null && systemctl --version &>/dev/null; then
    HAS_SYSTEMD=true
    return
  fi
  HAS_SYSTEMD=false
}

# ─── Pre-flight Checks ────────────────────────────────
check_root() {
  if [[ $EUID -ne 0 ]] && ! $DEV_MODE; then
    die "This installer must be run as root (use sudo ./install.sh)"
  fi
  if $DEV_MODE && [[ $EUID -ne 0 ]]; then
    warn "Running in dev mode without root — systemd service and firewall will be skipped"
  fi
}

check_os() {
  step "Checking operating system"
  
  if [[ -f /etc/os-release ]]; then
    # Source os-release safely
    while IFS='=' read -r key value; do
      # Remove surrounding quotes
      value="${value%\"}"
      value="${value#\"}"
      case "$key" in
        ID)          OS_ID="$value" ;;
        VERSION_ID)  OS_VERSION="$value" ;;
        PRETTY_NAME) OS_NAME="$value" ;;
        VERSION_CODENAME) export VERSION_CODENAME="$value" ;;
        UBUNTU_CODENAME) export UBUNTU_CODENAME="$value" ;;
      esac
    done < /etc/os-release
  else
    die "Cannot detect OS. /etc/os-release not found."
  fi

  # Determine Docker repo base ID and package manager
  case "$OS_ID" in
    ubuntu)
      ok "Detected: $OS_NAME"
      PKG_MANAGER="apt-get"
      DOCKER_REPO_ID="ubuntu"
      ;;
    debian)
      ok "Detected: $OS_NAME"
      PKG_MANAGER="apt-get"
      DOCKER_REPO_ID="debian"
      ;;
    linuxmint)
      ok "Detected: $OS_NAME"
      PKG_MANAGER="apt-get"
      # Linux Mint is based on Ubuntu — use Ubuntu's Docker repo
      DOCKER_REPO_ID="ubuntu"
      # Linux Mint 21.x = jammy, 22.x = noble
      if [[ -n "${UBUNTU_CODENAME:-}" ]]; then
        export VERSION_CODENAME="$UBUNTU_CODENAME"
      elif [[ "$OS_VERSION" == "21"* ]]; then
        export VERSION_CODENAME="jammy"
      elif [[ "$OS_VERSION" == "22"* ]]; then
        export VERSION_CODENAME="noble"
      else
        export VERSION_CODENAME="jammy"
      fi
      info "Using Ubuntu base ($VERSION_CODENAME) for package compatibility"
      ;;
    pop)
      ok "Detected: $OS_NAME"
      PKG_MANAGER="apt-get"
      DOCKER_REPO_ID="ubuntu"
      [[ -z "${VERSION_CODENAME:-}" ]] && export VERSION_CODENAME="jammy"
      ;;
    centos|rhel|rocky|almalinux|fedora)
      ok "Detected: $OS_NAME"
      PKG_MANAGER="dnf"
      DOCKER_REPO_ID="$OS_ID"
      ;;
    amzn|amazon)
      ok "Detected: Amazon Linux"
      PKG_MANAGER="yum"
      DOCKER_REPO_ID="centos"
      ;;
    *)
      warn "Detected: $OS_NAME (ID: $OS_ID) — not officially tested, continuing anyway"
      PKG_MANAGER="apt-get"
      DOCKER_REPO_ID="$OS_ID"
      ;;
  esac

  $IS_WSL && info "WSL environment detected — systemd support: $HAS_SYSTEMD"
}

check_arch() {
  step "Checking architecture"
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64|amd64)  ok "Architecture: x86_64 — supported" ;;
    aarch64|arm64) ok "Architecture: ARM64 — supported" ;;
    *)             die "Architecture $ARCH is not supported" ;;
  esac
}

check_existing() {
  if [[ -d "$INSTALL_DIR" ]] && [[ -f "$INSTALL_DIR/package.json" ]]; then
    warn "CBUP is already installed at $INSTALL_DIR"
    if ask_yes "Would you like to update/overwrite the existing installation?"; then
      info "Will update existing installation"
      return 1  # exists, update
    else
      info "Installation cancelled"
      exit 0
    fi
  fi
  return 0  # fresh install
}

# ─── Docker Install Path ──────────────────────────────
install_docker() {
  step "Installing via Docker"
  
  if ! command -v docker &>/dev/null; then
    info "Docker not found. Installing Docker Engine..."
    
    case "$PKG_MANAGER" in
      apt-get)
        apt-get update -qq 2>/dev/null || warn "apt-get update had warnings"
        apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1
        install -m 0755 -d /etc/apt/keyrings 2>/dev/null || true
        
        # Use DOCKER_REPO_ID (maps linuxmint → ubuntu, etc.)
        local repo_codename="${VERSION_CODENAME:-}"
        if [[ -z "$repo_codename" ]]; then
          repo_codename=$(lsb_release -cs 2>/dev/null || echo "stable")
        fi
        
        curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO_ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        chmod a+r /etc/apt/keyrings/docker.gpg 2>/dev/null
        
        echo "deb [arch=$(dpkg --print-architecture 2>/dev/null || echo 'amd64') signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DOCKER_REPO_ID} ${repo_codename} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq 2>/dev/null || warn "apt-get update had warnings"
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1 \
          || die "Failed to install Docker packages"
        ;;
      dnf|yum)
        $PKG_MANAGER install -y -q dnf-plugins-core > /dev/null 2>&1 || true
        $PKG_MANAGER config-manager --add-repo "https://download.docker.com/linux/${DOCKER_REPO_ID}/docker-ce.repo" > /dev/null 2>&1
        $PKG_MANAGER install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1 \
          || die "Failed to install Docker packages"
        ;;
    esac
    
    # Start Docker — handle WSL (no systemd) vs native
    if $HAS_SYSTEMD; then
      systemctl enable --now docker > /dev/null 2>&1 || warn "systemctl enable docker failed — try 'sudo service docker start'"
    else
      warn "No systemd detected — start Docker manually: sudo service docker start"
      service docker start 2>/dev/null || dockerd &>/dev/null || warn "Could not auto-start Docker. Please run: sudo dockerd &"
    fi
    
    ok "Docker installed: $(docker --version 2>/dev/null || echo 'installed (start manually)')"
  else
    ok "Docker already installed: $(docker --version)"
  fi

  # Create Dockerfile
  info "Preparing Docker build files..."
  
  mkdir -p "$INSTALL_DIR"
  cat > "$INSTALL_DIR/Dockerfile" << 'DOCKERFILE'
FROM node:20-slim AS base
RUN apt-get update && apt-get install -y openssl unzip ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Install bun
RUN npm install -g bun@1.2.2 || npm install -g bun

# Dependencies
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile 2>/dev/null || bun install

# Build
COPY . .
RUN bun run build

# Production
FROM node:20-slim AS runner
RUN apt-get update && apt-get install -y openssl curl ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
ENV DATABASE_URL="file:/app/data/cbup.db"

RUN addgroup --system --gid 1001 cbup 2>/dev/null || groupadd -r cbup -g 1001
RUN adduser --system --uid 1001 cbup 2>/dev/null || useradd -r -u 1001 cbup

COPY --from=base /app/.next/standalone ./
COPY --from=base /app/.next/static ./.next/static
COPY --from=base /app/public ./public

RUN mkdir -p /app/data && chown -R cbup:cbup /app
USER cbup

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/ || exit 1

CMD ["node", "server.js"]
DOCKERFILE

  # Create docker-compose.yml
  cat > "$INSTALL_DIR/docker-compose.yml" << YML
version: "3.8"

services:
  cbup:
    build: .
    container_name: cyber-brief-up
    restart: unless-stopped
    ports:
      - "${PORT:-3000}:3000"
    volumes:
      - cbup-data:/app/data
      - cbup-logs:/app/logs
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
  cbup-logs:
    driver: local
YML

  # Build and start
  cd "$INSTALL_DIR"
  info "Building CBUP Docker image (this may take a few minutes)..."
  docker compose build --quiet 2>&1 | tail -3 || docker compose build 2>&1 | tail -5
  docker compose up -d 2>&1
  
  ok "CBUP is running in Docker on port $PORT"
}

# ─── Bare-Metal Install Path ──────────────────────────
install_bun() {
  step "Installing Bun runtime"
  
  if command -v bun &>/dev/null; then
    ok "Bun already installed: $(bun --version)"
    return
  fi

  info "Downloading Bun..."
  BUN_INSTALL="/usr/local"
  
  # Ensure unzip is available (needed by Bun installer, especially on WSL)
  case "$PKG_MANAGER" in
    apt-get) apt-get install -y -qq unzip > /dev/null 2>&1 || true ;;
    dnf)     dnf install -y -q unzip > /dev/null 2>&1 || true ;;
    yum)     yum install -y -q unzip > /dev/null 2>&1 || true ;;
  esac

  # Try specific version first, then latest
  curl -fsSL https://bun.sh/install | BUN_INSTALL="$BUN_INSTALL" bash -s "bun-v1.2.2" > /dev/null 2>&1 \
    || curl -fsSL https://bun.sh/install | BUN_INSTALL="$BUN_INSTALL" bash > /dev/null 2>&1 \
    || die "Failed to install Bun. Try manually: curl -fsSL https://bun.sh/install | bash"

  export PATH="$BUN_INSTALL/bin:$PATH"
  
  # Create symlink
  if [[ -f "$BUN_INSTALL/bin/bun" ]]; then
    ln -sf "$BUN_INSTALL/bin/bun" /usr/local/bin/bun 2>/dev/null || true
  fi
  
  # Verify
  if command -v bun &>/dev/null; then
    ok "Bun installed: $(bun --version)"
  else
    # WSL PATH issue — add to profile
    warn "Bun installed but not in PATH. Adding to /etc/profile.d/cbup.sh"
    mkdir -p /etc/profile.d
    echo "export PATH=\"\$PATH:$BUN_INSTALL/bin\"" > /etc/profile.d/cbup.sh
    chmod +x /etc/profile.d/cbup.sh
    export PATH="$PATH:$BUN_INSTALL/bin"
    
    if command -v bun &>/dev/null; then
      ok "Bun installed: $(bun --version) (PATH updated)"
    else
      die "Bun installed but cannot be found. Log out and back in, or run: export PATH=\$PATH:$BUN_INSTALL/bin"
    fi
  fi
}

install_prerequisites() {
  step "Installing system prerequisites"

  case "$PKG_MANAGER" in
    apt-get)
      apt-get update -qq 2>/dev/null || warn "apt-get update had warnings"
      apt-get install -y -qq curl git build-essential libssl-dev ca-certificates unzip > /dev/null 2>&1
      # WSL: ensure procps is installed (for free, uptime)
      if $IS_WSL; then
        apt-get install -y -qq procps iproute2 > /dev/null 2>&1 || true
      fi
      ;;
    dnf)
      dnf install -y -q curl git gcc gcc-c++ make openssl-devel ca-certificates unzip > /dev/null 2>&1
      ;;
    yum)
      yum install -y -q curl git gcc make openssl-devel ca-certificates unzip > /dev/null 2>&1
      ;;
  esac
  ok "System prerequisites installed"
}

clone_or_copy_repo() {
  step "Setting up application files"

  IS_UPDATE=$1
  CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

  if $IS_UPDATE; then
    info "Updating existing installation at $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    if [[ -d .git ]]; then
      git pull origin "$BRANCH" 2>&1 || warn "git pull failed — files may have been modified locally"
    fi
  elif [[ -f "$CURRENT_DIR/package.json" ]]; then
    info "Installing from local source ($CURRENT_DIR)..."
    if [[ "$CURRENT_DIR" != "$INSTALL_DIR" ]]; then
      rm -rf "$INSTALL_DIR"
      cp -r "$CURRENT_DIR" "$INSTALL_DIR"
    fi
  else
    REPO=$(ask "Git repository URL" "$REPO_URL")
    info "Cloning from $REPO (branch: $BRANCH)..."
    rm -rf "$INSTALL_DIR"
    git clone --branch "$BRANCH" --depth 1 "$REPO" "$INSTALL_DIR" 2>&1 || die "Failed to clone repository"
  fi

  ok "Application files ready at $INSTALL_DIR"
}

install_dependencies() {
  step "Installing Node.js dependencies"
  
  cd "$INSTALL_DIR"

  info "Running bun install..."
  bun install 2>&1 | tail -5
  ok "Dependencies installed"
}

setup_database() {
  step "Setting up database"

  cd "$INSTALL_DIR"

  if ! $DEV_MODE; then
    # Create data directory
    mkdir -p "$DATA_DIR"
    export DATABASE_URL="file:$DATA_DIR/cbup.db"
    
    # Write .env for future use
    cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="file:$DATA_DIR/cbup.db"
NODE_ENV=production
PORT=$PORT
ENV
  else
    # Dev mode — use local db directory
    mkdir -p "$INSTALL_DIR/db"
    export DATABASE_URL="file:$INSTALL_DIR/db/custom.db"
    
    cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="file:./db/custom.db"
NODE_ENV=development
PORT=$PORT
ENV
  fi

  info "Pushing database schema..."
  bun run db:push 2>&1 | tail -5
  
  if $DEV_MODE; then
    ok "Database initialized at $INSTALL_DIR/db/custom.db"
  else
    ok "Database initialized at $DATA_DIR/cbup.db"
  fi
}

build_application() {
  step "Building production bundle"
  
  cd "$INSTALL_DIR"

  if $DEV_MODE; then
    ok "Skipping production build (dev mode)"
    return
  fi

  info "Running next build (this may take a minute)..."
  bun run build 2>&1 | tail -10
  ok "Production build complete"
}

setup_systemd() {
  step "Setting up system service"

  # Skip systemd setup in dev mode or when systemd is not available
  if ! $HAS_SYSTEMD; then
    warn "systemd not detected — skipping service setup"
    warn "To run CBUP manually: cd $INSTALL_DIR && bun run dev"
    if $IS_WSL; then
      warn ""
      warn "WSL users: Enable systemd for full service management:"
      warn "  1. Create or edit /etc/wsl.conf:"
      warn "     [boot]"
      warn "     systemd=true"
      warn "  2. Restart WSL: wsl --shutdown (from PowerShell)"
      warn "  3. Re-run this installer"
    fi
    return
  fi

  if $DEV_MODE; then
    info "Skipping systemd setup (dev mode)"
    return
  fi

  USER_EXISTS=$(id -u cbup 2>/dev/null || echo "")

  if [[ -z "$USER_EXISTS" ]]; then
    useradd -r -s /usr/sbin/nologin -d "$INSTALL_DIR" cbup 2>/dev/null \
      || adduser --system --no-create-home --shell /usr/sbin/nologin cbup 2>/dev/null \
      || warn "Could not create cbup user — using current user"
    ok "Created system user: cbup"
  fi

  # Set permissions
  if id cbup &>/dev/null; then
    chown -R cbup:cbup "$INSTALL_DIR" 2>/dev/null || true
    chown -R cbup:cbup "$DATA_DIR" 2>/dev/null || true
    mkdir -p "$LOG_DIR" && chown cbup:cbup "$LOG_DIR" 2>/dev/null || true
  fi

  # Resolve bun path
  local bun_path
  bun_path="$(which bun 2>/dev/null || echo "/usr/local/bin/bun")"

  # Create systemd service
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" << SVC
[Unit]
Description=Cyber Brief Unified Platform
After=network-online.target network.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=cbup
Group=cbup
WorkingDirectory=$INSTALL_DIR
Environment=NODE_ENV=production
Environment=PORT=$PORT
Environment=DATABASE_URL=file:$DATA_DIR/cbup.db
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=$bun_path run start
Restart=always
RestartSec=5
TimeoutStartSec=120
StandardOutput=append:$LOG_DIR/cbup.log
StandardError=append:$LOG_DIR/cbup-error.log

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR $DATA_DIR $LOG_DIR
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SVC

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" 2>/dev/null
  ok "Systemd service created: ${SERVICE_NAME}.service"
}

setup_firewall() {
  step "Configuring firewall"

  # Skip in WSL — no host firewall inside WSL
  if $IS_WSL; then
    info "WSL detected — firewall is managed by Windows host"
    info "Ensure port $PORT is accessible: check Windows Firewall settings"
    return
  fi

  # Skip in dev mode
  if $DEV_MODE; then
    info "Skipping firewall setup (dev mode)"
    return
  fi

  if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
    ufw allow "$PORT/tcp" > /dev/null 2>&1
    ok "UFW rule added: port $PORT/tcp"
  elif command -v firewall-cmd &>/dev/null && $HAS_SYSTEMD && systemctl is-active firewalld &>/dev/null; then
    firewall-cmd --permanent --add-port="$PORT/tcp" > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
    ok "Firewalld rule added: port $PORT/tcp"
  elif command -v iptables &>/dev/null; then
    warn "iptables detected — manual firewall rule may be needed:"
    warn "  sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT"
  else
    info "No firewall detected — port $PORT should be open by default"
  fi
}

start_service() {
  step "Starting CBUP"

  if $DEV_MODE; then
    info "Starting in development mode..."
    cd "$INSTALL_DIR"
    echo ""
    echo -e "${GREEN}${BOLD}  Run the following to start the dev server:${NC}"
    echo -e "    cd $INSTALL_DIR && bun run dev"
    echo ""
    echo -e "  ${BOLD}Or start it now in the background:${NC}"
    echo -e "    nohup bun run dev > $INSTALL_DIR/dev.log 2>&1 &"
    echo ""
    return
  fi

  if $USE_DOCKER; then
    cd "$INSTALL_DIR"
    docker compose up -d 2>&1 | tail -3
    return
  fi

  if ! $HAS_SYSTEMD; then
    warn "No systemd — start CBUP manually:"
    warn "  cd $INSTALL_DIR && DATABASE_URL=\"file:$DATA_DIR/cbup.db\" NODE_ENV=production PORT=$PORT bun run start"
    return
  fi

  systemctl start "$SERVICE_NAME" 2>&1
  sleep 3
  
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "CBUP is running!"
  else
    error "Service failed to start. Check logs:"
    error "  journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
    error "  cat $LOG_DIR/cbup-error.log"
    return 1
  fi
}

# ─── Management CLI ───────────────────────────────────
install_cli() {
  step "Installing management CLI"

  local cli_target="/usr/local/bin/cbup"
  
  # In dev mode without root, install to user's bin
  if $DEV_MODE && [[ $EUID -ne 0 ]]; then
    mkdir -p "$HOME/.local/bin"
    cli_target="$HOME/.local/bin/cbup"
    warn "Installing CLI to $cli_target (no root in dev mode)"
    warn "Ensure ~/.local/bin is in your PATH"
  fi

  cat > "$cli_target" << 'CLI'
#!/usr/bin/env bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/cbup"
SERVICE_NAME="cbup"
DATA_DIR="/var/lib/cbup"
LOG_DIR="/var/log/cbup"
BACKUP_DIR="/var/backups/cbup"
PORT="3000"

# Detect if we're in WSL
IS_WSL=false
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  IS_WSL=true
fi

# Detect systemd
HAS_SYSTEMD=false
if [[ "$(readlink -f /proc/1/exe 2>/dev/null)" == *systemd* ]]; then
  HAS_SYSTEMD=true
elif command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
  HAS_SYSTEMD=true
fi

# Read PORT from .env if available
if [[ -f "$INSTALL_DIR/.env" ]]; then
  PORT=$(grep -E "^PORT=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "3000")
  PORT="${PORT:-3000}"
fi

usage() {
  cat <<HELP
${BOLD}Cyber Brief Unified Platform — Management CLI${NC}

Usage: cbup <command> [options]

${BOLD}Commands:${NC}
  start              Start the CBUP service
  stop               Stop the CBUP service
  restart            Restart the CBUP service
  status             Show service status and health
  logs [lines]       Tail service logs (default: 50 lines)
  update             Update to the latest version
  backup             Create a database backup
  restore <file>     Restore from a backup file
  reset-db           Reset the database (DESTRUCTIVE)
  shell              Open a shell in the app directory
  doctor             Run diagnostics checks
  uninstall          Remove CBUP completely

${BOLD}Examples:${NC}
  cbup start
  cbup logs 100
  cbup update
  cbup backup
  cbup doctor
HELP
}

cmd_start() {
  echo -e "${CYAN}[CBUP]${NC} Starting service..."

  # Docker mode
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
      cd "$INSTALL_DIR" && docker compose up -d 2>&1 | tail -3
      sleep 2
      cmd_status
      return
    fi
  fi

  # Systemd mode
  if $HAS_SYSTEMD && systemctl list-unit-files "${SERVICE_NAME}.service" &>/dev/null; then
    systemctl start "$SERVICE_NAME" 2>&1
    sleep 2
    cmd_status
    return
  fi

  # Fallback: manual start
  echo -e "${YELLOW}[CBUP]${NC} No service manager found. Starting manually..."
  cd "$INSTALL_DIR"
  if [[ -f .env ]]; then
    set -a; source .env; set +a
  fi
  nohup bun run start > "${LOG_DIR:-/tmp}/cbup.log" 2>&1 &
  local pid=$!
  echo -e "${GREEN}[CBUP]${NC} Started with PID $pid"
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    echo -e "${GREEN}[CBUP]${NC} CBUP is running (PID: $pid, Port: $PORT)"
  else
    echo -e "${RED}[CBUP]${NC} Process exited. Check ${LOG_DIR:-/tmp}/cbup.log"
  fi
}

cmd_stop() {
  echo -e "${CYAN}[CBUP]${NC} Stopping service..."

  # Docker
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
      cd "$INSTALL_DIR" && docker compose down 2>&1
      echo -e "${GREEN}[CBUP]${NC} Service stopped."
      return
    fi
  fi

  # Systemd
  if $HAS_SYSTEMD && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME" 2>&1
    echo -e "${GREEN}[CBUP]${NC} Service stopped."
    return
  fi

  # Fallback: kill by process name
  pkill -f "bun run start" 2>/dev/null || true
  pkill -f "node.*server.js" 2>/dev/null || true
  echo -e "${GREEN}[CBUP]${NC} Service stopped."
}

cmd_restart() {
  echo -e "${CYAN}[CBUP]${NC} Restarting service..."
  cmd_stop
  sleep 1
  cmd_start
}

cmd_status() {
  echo -e "${BOLD}${CYAN}═══ Cyber Brief Unified Platform — Status ═══${NC}"
  echo ""

  # Service status
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
    echo -e "  Service:     ${GREEN}Running (Docker)${NC}"
    cd "$INSTALL_DIR" && docker compose ps 2>/dev/null | tail -n +2
  elif $HAS_SYSTEMD && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "  Service:     ${GREEN}Running (systemd)${NC}"
    echo -e "  Uptime:      $(systemctl show "$SERVICE_NAME" --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)"
  elif pgrep -f "bun.*start" &>/dev/null || pgrep -f "node.*server.js" &>/dev/null; then
    echo -e "  Service:     ${GREEN}Running (manual)${NC}"
  else
    echo -e "  Service:     ${RED}Stopped${NC}"
  fi

  # Version
  if [[ -f "$INSTALL_DIR/package.json" ]]; then
    VERSION=$(node -e "console.log(require('$INSTALL_DIR/package.json').version)" 2>/dev/null || echo "unknown")
    echo -e "  Version:     $VERSION"
  fi

  # Port
  echo -e "  Port:        $PORT"

  # Database
  local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
  if [[ -f "$db_file" ]]; then
    DB_SIZE=$(du -h "$db_file" | cut -f1)
    echo -e "  Database:    ${GREEN}OK${NC} ($DB_SIZE)"
  elif [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
    DB_SIZE=$(du -h "$INSTALL_DIR/db/custom.db" | cut -f1)
    echo -e "  Database:    ${GREEN}OK (dev)${NC} ($DB_SIZE)"
  else
    echo -e "  Database:    ${YELLOW}Not found${NC}"
  fi

  # Disk usage
  if [[ -d "$INSTALL_DIR" ]]; then
    DISK=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
    echo -e "  Disk Usage:  $DISK"
  fi

  # Environment info
  if $IS_WSL; then
    echo -e "  Runtime:     ${YELLOW}WSL${NC} (systemd: $HAS_SYSTEMD)"
  else
    echo -e "  Runtime:     Native Linux"
  fi

  # Last backup
  if [[ -d "${BACKUP_DIR:-/var/backups/cbup}" ]]; then
    LAST_BACKUP=$(ls -t "${BACKUP_DIR:-/var/backups/cbup}"/cbup-backup-*.db.gz 2>/dev/null | head -1)
    if [[ -n "$LAST_BACKUP" ]]; then
      # stat works on both Linux and WSL
      BACKUP_DATE=$(stat -c %y "$LAST_BACKUP" 2>/dev/null | cut -d. -f1 || stat -f "%Sm" "$LAST_BACKUP" 2>/dev/null)
      echo -e "  Last Backup: $BACKUP_DATE"
    fi
  fi

  echo ""
}

cmd_logs() {
  local lines="${1:-50}"
  
  # Docker
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
      cd "$INSTALL_DIR" && docker compose logs --tail="$lines" -f 2>&1
      return
    fi
  fi

  # Systemd
  if $HAS_SYSTEMD && systemctl list-unit-files "${SERVICE_NAME}.service" &>/dev/null; then
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager -f 2>&1
    return
  fi

  # Fallback: log file
  local log_file="${LOG_DIR:-/tmp}/cbup.log"
  if [[ -f "$log_file" ]]; then
    tail -n "$lines" -f "$log_file"
  else
    echo -e "${YELLOW}[CBUP]${NC} No log file found at $log_file"
  fi
}

cmd_update() {
  echo -e "${CYAN}[CBUP]${NC} Updating to the latest version..."
  
  cd "$INSTALL_DIR"

  # Backup before update
  cmd_backup
  
  if [[ -d .git ]]; then
    git fetch origin 2>&1 | tail -3
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master)
    if [[ "$LOCAL" == "$REMOTE" ]]; then
      echo -e "${GREEN}[CBUP]${NC} Already up to date."
      return
    fi
    git pull origin main 2>&1 || git pull origin master 2>&1
  else
    echo -e "${YELLOW}[CBUP]${NC} Not a git repo — cannot auto-update."
    echo -e "${YELLOW}[CBUP]${NC} Please manually update files in $INSTALL_DIR"
    return 1
  fi

  echo -e "${CYAN}[CBUP]${NC} Installing dependencies..."
  bun install 2>&1 | tail -3

  echo -e "${CYAN}[CBUP]${NC} Pushing database schema..."
  if [[ -f .env ]]; then
    set -a; source .env; set +a
  fi
  bun run db:push 2>&1 | tail -3

  echo -e "${CYAN}[CBUP]${NC} Building production bundle..."
  bun run build 2>&1 | tail -5

  cmd_restart
  echo -e "${GREEN}[CBUP]${NC} Update complete!"
}

cmd_backup() {
  mkdir -p "${BACKUP_DIR:-/var/backups/cbup}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.db"
  
  # Find the database file
  local db_file=""
  if [[ -f "${DATA_DIR:-/var/lib/cbup}/cbup.db" ]]; then
    db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
  elif [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
    db_file="$INSTALL_DIR/db/custom.db"
  fi

  if [[ -n "$db_file" ]]; then
    cp "$db_file" "$backup_file"
    gzip -f "$backup_file"
    echo -e "${GREEN}[CBUP]${NC} Backup created: ${backup_file}.gz ($(du -h "${backup_file}.gz" | cut -f1))"
  else
    echo -e "${YELLOW}[CBUP]${NC} No database to backup."
  fi
  
  # Keep only last 30 backups
  cd "${BACKUP_DIR:-/var/backups/cbup}" 2>/dev/null && ls -t cbup-backup-*.db.gz 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true
}

cmd_restore() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    echo -e "${RED}[CBUP]${NC} Usage: cbup restore <backup-file>"
    echo -e "${YELLOW}[CBUP]${NC} Available backups:"
    ls -lh "${BACKUP_DIR:-/var/backups/cbup}"/cbup-backup-*.db.gz 2>/dev/null || echo "  (none found)"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo -e "${RED}[CBUP]${NC} File not found: $file"
    return 1
  fi

  cmd_stop
  
  # Backup current before restoring
  cmd_backup

  # Determine target
  local target_db="${DATA_DIR:-/var/lib/cbup}/cbup.db"
  if [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
    target_db="$INSTALL_DIR/db/custom.db"
  fi
  mkdir -p "$(dirname "$target_db")"

  # Restore
  if [[ "$file" == *.gz ]]; then
    gunzip -c "$file" > "$target_db"
  else
    cp "$file" "$target_db"
  fi

  cmd_start
  echo -e "${GREEN}[CBUP]${NC} Database restored from $file"
}

cmd_reset_db() {
  echo -e "${RED}${BOLD}[WARNING]${NC} This will DELETE all data and reset the database!"
  read -rp "Type 'RESET' to confirm: " confirm
  if [[ "$confirm" != "RESET" ]]; then
    echo "Cancelled."
    return
  fi

  cmd_stop

  local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
  if [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
    db_file="$INSTALL_DIR/db/custom.db"
  fi
  rm -f "$db_file"

  cd "$INSTALL_DIR"
  if [[ -f .env ]]; then
    set -a; source .env; set +a
  fi
  bun run db:push 2>&1 | tail -3

  cmd_start
  echo -e "${GREEN}[CBUP]${NC} Database has been reset."
}

cmd_shell() {
  cd "$INSTALL_DIR" && exec bash
}

cmd_doctor() {
  echo -e "${BOLD}${CYAN}═══ CBUP Doctor — Diagnostics ═══${NC}"
  echo ""

  local errors=0

  # Environment
  echo -n "  Environment: "
  if $IS_WSL; then
    echo -e "${YELLOW}WSL${NC} (systemd: $HAS_SYSTEMD)"
  else
    echo -e "${GREEN}Native Linux${NC}"
  fi

  # Check service
  echo -n "  Service:      "
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
    echo -e "${GREEN}Running (Docker)${NC}"
  elif $HAS_SYSTEMD && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${GREEN}Running (systemd)${NC}"
  elif pgrep -f "bun.*start" &>/dev/null; then
    echo -e "${GREEN}Running (manual)${NC}"
  else
    echo -e "${RED}Not running${NC}"
    ((errors++))
  fi

  # Check bun
  echo -n "  Bun runtime:  "
  if command -v bun &>/dev/null; then
    echo -e "${GREEN}$(bun --version)${NC}"
  else
    echo -e "${RED}Not found${NC}"
    ((errors++))
  fi

  # Check database
  echo -n "  Database:     "
  local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
  if [[ ! -f "$db_file" ]] && [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
    db_file="$INSTALL_DIR/db/custom.db"
  fi
  if [[ -f "$db_file" ]]; then
    echo -e "${GREEN}OK ($(du -h "$db_file" | cut -f1))${NC}"
  else
    echo -e "${RED}Missing${NC}"
    ((errors++))
  fi

  # Check port — use ss, netstat, or /proc
  echo -n "  Port $PORT:    "
  local port_open=false
  if command -v ss &>/dev/null && ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    port_open=true
  elif command -v netstat &>/dev/null && netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    port_open=true
  elif [[ -f /proc/net/tcp ]]; then
    # Convert port to hex
    local port_hex
    port_hex=$(printf '%X' "$PORT")
    if grep -qi ":${port_hex} " /proc/net/tcp 2>/dev/null; then
      port_open=true
    fi
  fi
  if $port_open; then
    echo -e "${GREEN}Listening${NC}"
  else
    echo -e "${YELLOW}Not bound${NC}"
    ((errors++))
  fi

  # Check disk space
  echo -n "  Disk Space:   "
  local free_pct
  free_pct=$(df "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); printf "%d", $5}')
  if [[ -n "$free_pct" ]] && [[ "$free_pct" -lt 90 ]]; then
    echo -e "${GREEN}${free_pct}% used${NC}"
  elif [[ -n "$free_pct" ]]; then
    echo -e "${RED}${free_pct}% used — running low!${NC}"
    ((errors++))
  else
    echo -e "${YELLOW}Unable to check${NC}"
  fi

  # Check memory
  echo -n "  Memory:       "
  if command -v free &>/dev/null; then
    local mem_avail mem_total
    mem_avail=$(free -m 2>/dev/null | awk 'NR==2 {print $7}')
    mem_total=$(free -m 2>/dev/null | awk 'NR==2 {print $2}')
    if [[ -n "$mem_avail" ]]; then
      if [[ "$mem_avail" -gt 256 ]]; then
        echo -e "${GREEN}${mem_avail}MB free / ${mem_total}MB total${NC}"
      else
        echo -e "${YELLOW}${mem_avail}MB free / ${mem_total}MB total — low memory${NC}"
        ((errors++))
      fi
    else
      echo -e "${YELLOW}Unable to check${NC}"
    fi
  else
    echo -e "${YELLOW}free command not available${NC}"
  fi

  # Check connectivity
  echo -n "  HTTP Health:  "
  if command -v curl &>/dev/null; then
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
      echo -e "${GREEN}200 OK${NC}"
    else
      echo -e "${RED}${http_code}${NC}"
      ((errors++))
    fi
  else
    echo -e "${YELLOW}curl not available${NC}"
  fi

  # WSL-specific checks
  if $IS_WSL; then
    echo ""
    echo -e "  ${BOLD}WSL-Specific:${NC}"
    echo -n "  systemd:      "
    if $HAS_SYSTEMD; then
      echo -e "${GREEN}Enabled${NC}"
    else
      echo -e "${YELLOW}Not available — service management limited${NC}"
      echo -e "    Fix: Add [boot]\\nsystemd=true to /etc/wsl.conf, then wsl --shutdown"
    fi
  fi

  echo ""
  if [[ "$errors" -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All checks passed! ✓${NC}"
  else
    echo -e "${RED}${BOLD}$errors issue(s) found.${NC}"
  fi
  echo ""
}

cmd_uninstall() {
  echo -e "${RED}${BOLD}WARNING: This will completely remove Cyber Brief Unified Platform!${NC}"
  read -rp "Type 'UNINSTALL' to confirm: " confirm
  if [[ "$confirm" != "UNINSTALL" ]]; then
    echo "Cancelled."
    return
  fi

  echo -e "${CYAN}[CBUP]${NC} Stopping service..."

  # Docker
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null; then
    cd "$INSTALL_DIR" && docker compose down -v 2>/dev/null || true
  fi

  # Systemd
  if $HAS_SYSTEMD; then
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload 2>/dev/null || true
  fi

  # Kill manual processes
  pkill -f "bun.*start" 2>/dev/null || true
  pkill -f "node.*server.js" 2>/dev/null || true

  echo -e "${CYAN}[CBUP]${NC} Removing files..."
  rm -rf "$INSTALL_DIR" 2>/dev/null || sudo rm -rf "$INSTALL_DIR" 2>/dev/null || true
  rm -rf "$LOG_DIR" 2>/dev/null || sudo rm -rf "$LOG_DIR" 2>/dev/null || true
  rm -rf "$BACKUP_DIR" 2>/dev/null || sudo rm -rf "$BACKUP_DIR" 2>/dev/null || true

  # Remove user
  id cbup &>/dev/null && userdel cbup 2>/dev/null || true

  # Remove CLI
  rm -f /usr/local/bin/cbup 2>/dev/null || true
  rm -f "$HOME/.local/bin/cbup" 2>/dev/null || true
  rm -f /etc/profile.d/cbup.sh 2>/dev/null || true

  echo -e "${GREEN}${BOLD}[CBUP]${NC} Cyber Brief Unified Platform has been completely removed."
  echo -e "${YELLOW}[CBUP]${NC} Database at $DATA_DIR was preserved. Remove manually if desired:"
  echo -e "${YELLOW}[CBUP]${NC}   rm -rf $DATA_DIR"
}

case "${1:-}" in
  start)    cmd_start ;;
  stop)     cmd_stop ;;
  restart)  cmd_restart ;;
  status)   cmd_status ;;
  logs)     cmd_logs "${2:-50}" ;;
  update)   cmd_update ;;
  backup)   cmd_backup ;;
  restore)  cmd_restore "${2:-}" ;;
  reset-db) cmd_reset_db ;;
  shell)    cmd_shell ;;
  doctor)   cmd_doctor ;;
  uninstall) cmd_uninstall ;;
  -h|--help|help|"") usage ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    usage
    exit 1
    ;;
esac
CLI

  chmod +x "$cli_target"
  ok "Management CLI installed: $cli_target (run 'cbup --help')"
}

# ─── Uninstall ────────────────────────────────────────
uninstall() {
  if command -v cbup &>/dev/null; then
    cbup uninstall
  else
    if $HAS_SYSTEMD; then
      systemctl stop "$SERVICE_NAME" 2>/dev/null || true
      systemctl disable "$SERVICE_NAME" 2>/dev/null || true
      rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
      systemctl daemon-reload 2>/dev/null
    fi
    rm -rf "$INSTALL_DIR" "$LOG_DIR"
    rm -f /usr/local/bin/cbup "$HOME/.local/bin/cbup"
    rm -f /etc/profile.d/cbup.sh
    echo -e "${GREEN}[CBUP]${NC} Uninstalled."
  fi
}

# ─── Validation Tests ─────────────────────────────────
run_tests() {
  step "Running validation tests"

  local passed=0
  local failed=0
  local skipped=0

  test_pass() { ((passed++)); echo -e "  ${GREEN}✓ PASS${NC}: $1"; }
  test_fail() { ((failed++)); echo -e "  ${RED}✗ FAIL${NC}: $1 — $2"; }
  test_skip() { ((skipped++)); echo -e "  ${YELLOW}⊘ SKIP${NC}: $1 — $2"; }

  echo ""
  echo -e "${BOLD}Test Suite: OS Compatibility${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T1: OS detection
  if [[ -f /etc/os-release ]]; then
    test_pass "OS detection (/etc/os-release exists)"
  else
    test_fail "OS detection" "/etc/os-release not found"
  fi

  # T2: Ubuntu compatibility
  if [[ "$OS_ID" == "ubuntu" ]]; then
    test_pass "Ubuntu detected ($OS_NAME)"
  else
    test_skip "Ubuntu specific tests" "Running on $OS_ID"
  fi

  # T3: Linux Mint compatibility
  if [[ "$OS_ID" == "linuxmint" ]]; then
    test_pass "Linux Mint detected ($OS_NAME)"
    # Check Ubuntu codename mapping
    if [[ -n "${UBUNTU_CODENAME:-}" ]] || [[ -n "${VERSION_CODENAME:-}" ]]; then
      test_pass "Linux Mint Ubuntu codename resolved (${UBUNTU_CODENAME:-$VERSION_CODENAME})"
    else
      test_fail "Linux Mint codename" "Could not resolve Ubuntu base codename"
    fi
  else
    test_skip "Linux Mint specific tests" "Running on $OS_ID"
  fi

  # T4: WSL detection
  if $IS_WSL; then
    test_pass "WSL detected"
    if $HAS_SYSTEMD; then
      test_pass "WSL systemd available"
    else
      test_pass "WSL without systemd (graceful fallback)"
    fi
  else
    test_pass "Native Linux (non-WSL)"
    test_skip "WSL specific tests" "Not running in WSL"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Package Manager${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T5: Package manager
  if [[ -n "$PKG_MANAGER" ]]; then
    test_pass "Package manager resolved ($PKG_MANAGER)"
  else
    test_fail "Package manager" "Could not determine package manager"
  fi

  # T6: apt-get available
  if command -v apt-get &>/dev/null; then
    test_pass "apt-get available"
  else
    test_skip "apt-get" "Not available on this system"
  fi

  # T7: Docker repo ID mapping
  if [[ "$DOCKER_REPO_ID" == "ubuntu" && "$OS_ID" == "linuxmint" ]]; then
    test_pass "Docker repo ID mapping (linuxmint → ubuntu)"
  elif [[ "$DOCKER_REPO_ID" == "$OS_ID" ]]; then
    test_pass "Docker repo ID (direct: $DOCKER_REPO_ID)"
  elif [[ -n "$DOCKER_REPO_ID" ]]; then
    test_pass "Docker repo ID resolved ($OS_ID → $DOCKER_REPO_ID)"
  else
    test_fail "Docker repo ID" "Could not determine"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Prerequisites${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T8: curl
  if command -v curl &>/dev/null; then
    test_pass "curl available ($(curl --version 2>/dev/null | head -1 | awk '{print $2}'))"
  else
    test_fail "curl" "Not found — install required"
  fi

  # T9: git
  if command -v git &>/dev/null; then
    test_pass "git available ($(git --version | awk '{print $3}'))"
  else
    test_fail "git" "Not found — install required"
  fi

  # T10: unzip (Bun installer dependency)
  if command -v unzip &>/dev/null; then
    test_pass "unzip available (Bun installer dependency)"
  else
    test_fail "unzip" "Not found — Bun installer requires unzip"
  fi

  # T11: Build tools
  if command -v gcc &>/dev/null || command -v cc &>/dev/null; then
    test_pass "C compiler available"
  elif dpkg -l build-essential 2>/dev/null | grep -q "ii"; then
    test_pass "build-essential installed"
  else
    test_fail "Build tools" "No C compiler found — native modules may fail"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Runtime${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T12: Bun
  if command -v bun &>/dev/null; then
    test_pass "Bun runtime ($(bun --version))"
  else
    test_skip "Bun runtime" "Not installed yet (installer will handle this)"
  fi

  # T13: Node.js (fallback)
  if command -v node &>/dev/null; then
    test_pass "Node.js available ($(node --version))"
  else
    test_skip "Node.js" "Not installed (not required with Bun)"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Service Management${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T14: systemd
  if $HAS_SYSTEMD; then
    test_pass "systemd available"
  else
    test_pass "No systemd (installer handles gracefully)"
    if $IS_WSL; then
      test_pass "WSL systemd fallback documented"
    fi
  fi

  # T15: systemctl
  if command -v systemctl &>/dev/null; then
    if systemctl --version &>/dev/null 2>&1; then
      test_pass "systemctl functional"
    else
      test_fail "systemctl" "Command exists but not functional (WSL?)"
    fi
  else
    test_skip "systemctl" "Not available"
  fi

  # T16: service command (WSL fallback)
  if command -v service &>/dev/null; then
    test_pass "service command available (WSL fallback)"
  else
    test_skip "service command" "Not available"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Network & Ports${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T17: Port check tool
  if command -v ss &>/dev/null; then
    test_pass "ss command available for port checking"
  elif command -v netstat &>/dev/null; then
    test_pass "netstat available for port checking"
  elif [[ -f /proc/net/tcp ]]; then
    test_pass "/proc/net/tcp available for port checking"
  else
    test_fail "Port check" "No tool available (ss, netstat, /proc/net/tcp)"
  fi

  # T18: Port availability
  if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":3000 "; then
      test_fail "Port 3000" "Already in use"
    else
      test_pass "Port 3000 available"
    fi
  elif [[ -f /proc/net/tcp ]]; then
    local port_hex
    port_hex=$(printf '%X' 3000)
    if grep -qi ":${port_hex} " /proc/net/tcp 2>/dev/null; then
      test_fail "Port 3000" "Already in use (via /proc/net/tcp)"
    else
      test_pass "Port 3000 available (via /proc/net/tcp)"
    fi
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Filesystem & Permissions${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T19: /opt writable
  if [[ -w /opt ]] || [[ $EUID -eq 0 ]]; then
    test_pass "/opt is writable (or running as root)"
  else
    test_fail "/opt" "Not writable and not root"
  fi

  # T20: /var/lib writable
  if [[ -w /var/lib ]] || [[ $EUID -eq 0 ]]; then
    test_pass "/var/lib is writable (or running as root)"
  else
    test_fail "/var/lib" "Not writable and not root"
  fi

  # T21: stat command
  if stat --version &>/dev/null 2>&1 || command -v stat &>/dev/null; then
    test_pass "stat command available"
  else
    test_fail "stat" "Not available — backup dates won't work"
  fi

  # T22: gzip available
  if command -v gzip &>/dev/null; then
    test_pass "gzip available (backup compression)"
  else
    test_fail "gzip" "Not available — backups won't be compressed"
  fi

  echo ""
  echo -e "${BOLD}Test Suite: Docker (if applicable)${NC}"
  echo -e "${DIM}────────────────────────────────────${NC}"

  # T23: Docker
  if command -v docker &>/dev/null; then
    test_pass "Docker available ($(docker --version 2>/dev/null | awk '{print $3}'))"
    if docker info &>/dev/null 2>&1; then
      test_pass "Docker daemon running"
    else
      test_fail "Docker daemon" "Not running — start with: sudo systemctl start docker"
    fi
    if docker compose version &>/dev/null 2>&1; then
      test_pass "Docker Compose available"
    else
      test_fail "Docker Compose" "Not available"
    fi
  else
    test_skip "Docker" "Not installed (use --docker to install)"
  fi

  echo ""
  echo -e "═══════════════════════════════════════"
  echo -e "  ${BOLD}Results: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}, ${YELLOW}$skipped skipped${NC}"
  echo -e "═══════════════════════════════════════"
  echo ""

  if [[ $failed -gt 0 ]]; then
    echo -e "${YELLOW}Some tests failed. Review the output above.${NC}"
    echo -e "${YELLOW}Most issues can be resolved by the installer automatically.${NC}"
    return 1
  else
    echo -e "${GREEN}All tests passed! This system is ready for CBUP installation.${NC}"
    return 0
  fi
}

# ─── Summary ──────────────────────────────────────────
print_summary() {
  separator
  echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
  separator
  echo ""
  echo -e "  ${BOLD}Cyber Brief Unified Platform${NC} is now running on:"
  echo -e "  ${CYAN}  http://localhost:${PORT}${NC}"
  echo ""

  if $IS_WSL; then
    echo -e "  ${BOLD}WSL Access:${NC}"
    echo -e "    From Windows browser: http://localhost:${PORT}"
    echo -e "    If not accessible: check WSL network settings"
    echo ""
  fi

  echo -e "  ${BOLD}Management commands:${NC}"
  echo -e "    cbup status     — Check service status"
  echo -e "    cbup logs       — View logs"
  echo -e "    cbup restart    — Restart service"
  echo -e "    cbup update     — Update to latest version"
  echo -e "    cbup backup     — Backup database"
  echo -e "    cbup doctor     — Run diagnostics"
  echo -e "    cbup --help     — All commands"
  echo ""

  if ! $DEV_MODE && ! $USE_DOCKER; then
    echo -e "  ${BOLD}Files:${NC}"
    echo -e "    App:        $INSTALL_DIR"
    echo -e "    Database:   $DATA_DIR/cbup.db"
    echo -e "    Logs:       $LOG_DIR/"
    echo -e "    Backups:    $BACKUP_DIR/"
    echo ""
  elif $DEV_MODE; then
    echo -e "  ${BOLD}Files:${NC}"
    echo -e "    App:        $INSTALL_DIR"
    echo -e "    Database:   $INSTALL_DIR/db/custom.db"
    echo ""
  fi

  if $USE_DOCKER; then
    echo -e "  ${BOLD}Docker:${NC}"
    echo -e "    cd $INSTALL_DIR && docker compose logs -f"
    echo ""
  elif $HAS_SYSTEMD && ! $DEV_MODE; then
    echo -e "  ${BOLD}Service:${NC}"
    echo -e "    systemctl ${SERVICE_NAME} {start|stop|restart|status}"
    echo -e "    journalctl -u ${SERVICE_NAME} -f"
    echo ""
  fi

  if $IS_WSL && ! $HAS_SYSTEMD; then
    echo -e "  ${BOLD}WSL Notes:${NC}"
    echo -e "    CBUP is running as a background process"
    echo -e "    Use 'cbup stop' and 'cbup start' to manage it"
    echo -e "    To enable systemd support, add to /etc/wsl.conf:"
    echo -e "      [boot]"
    echo -e "      systemd=true"
    echo -e "    Then restart WSL: wsl --shutdown"
    echo ""
  fi

  separator
}

# ─── Parse Args ───────────────────────────────────────
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --docker)       USE_DOCKER=true; shift ;;
      --dev)          DEV_MODE=true; shift ;;
      --port)         PORT="$2"; shift 2 ;;
      --yes|-y)       NONINTERACTIVE=true; shift ;;
      --uninstall)    UNINSTALL=true; shift ;;
      --test)         RUN_TESTS=true; shift ;;
      --branch)       BRANCH="$2"; shift 2 ;;
      --help|-h)      echo "Usage: $0 [--docker] [--dev] [--port N] [--yes] [--uninstall] [--test] [--branch X]"; exit 0 ;;
      *)              die "Unknown option: $1" ;;
    esac
  done
}

# ─── Main ─────────────────────────────────────────────
main() {
  parse_args "$@"
  banner

  # Always detect WSL and systemd first
  detect_wsl
  detect_systemd

  if $RUN_TESTS; then
    check_os  # Need OS detection for tests
    run_tests
    exit $?
  fi

  if $UNINSTALL; then
    check_root
    uninstall
    exit 0
  fi

  check_root
  check_os
  check_arch

  if $USE_DOCKER; then
    info "Install mode: Docker"
    check_existing || true
    install_docker
    install_cli
  elif $DEV_MODE; then
    info "Install mode: Development (no systemd, no root needed)"
    IS_NEW=true
    check_existing || IS_NEW=false
    install_prerequisites
    install_bun
    clone_or_copy_repo $([[ "$IS_NEW" == "false" ]] && echo true || echo false)
    install_dependencies
    setup_database
    build_application
    start_service
    install_cli
  else
    info "Install mode: Bare Metal (systemd)"
    IS_NEW=true
    check_existing || IS_NEW=false
    install_prerequisites
    install_bun
    clone_or_copy_repo $([[ "$IS_NEW" == "false" ]] && echo true || echo false)
    install_dependencies
    setup_database
    build_application
    setup_systemd
    setup_firewall
    start_service
    install_cli
  fi

  print_summary
}

main "$@"
