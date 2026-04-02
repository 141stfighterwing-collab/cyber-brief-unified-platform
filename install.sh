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
# Database: SQLite (default), MySQL, PostgreSQL, MongoDB, SQL Server
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/141stfighterwing-collab/cyber-brief-unified-platform/main/install.sh | sudo bash
#   ./install.sh                      # Interactive install
#   ./install.sh --docker             # Docker install
#   ./install.sh --dev                # Development mode (no systemd, no root needed)
#   ./install.sh --port 8080          # Custom port
#   ./install.sh --yes                # Non-interactive
#   ./install.sh --db mysql           # Use MySQL database
#   ./install.sh --db postgresql      # Use PostgreSQL database
#   ./install.sh --db mongodb         # Use MongoDB database
#   ./install.sh --db mssql           # Use SQL Server database
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

# Database configuration
DB_PROVIDER="sqlite"
DB_CONTAINER=""

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

# ─── Database Selection ───────────────────────────────
select_database() {
  step "Selecting database backend"

  if $NONINTERACTIVE; then
    info "Non-interactive mode — using default database: $DB_PROVIDER"
    return
  fi

  echo -e "${BOLD}"
  cat << 'DBMENU'
  ╔══════════════════════════════════════════╗
  ║        Select Database Backend           ║
  ╠══════════════════════════════════════════╣
  ║  1) SQLite    (default, zero config)     ║
  ║  2) MySQL     (production recommended)   ║
  ║  3) PostgreSQL (production recommended)  ║
  ║  4) MongoDB   (NoSQL alternative)       ║
  ║  5) SQL Server (Microsoft environments)  ║
  ╚══════════════════════════════════════════╝
DBMENU
  echo -e "${NC}"

  local choice
  read -rp "$(echo -e "${CYAN}Choose database [1-5]${NC} (default: ${GREEN}1${NC}): ")" choice
  choice="${choice:-1}"

  case "$choice" in
    1) DB_PROVIDER="sqlite" ;;
    2) DB_PROVIDER="mysql" ;;
    3) DB_PROVIDER="postgresql" ;;
    4) DB_PROVIDER="mongodb" ;;
    5) DB_PROVIDER="mssql" ;;
    *) DB_PROVIDER="sqlite"; warn "Invalid choice '$choice' — defaulting to SQLite" ;;
  esac

  ok "Database selected: $DB_PROVIDER"
}

# ─── Compose File Helper ─────────────────────────────
get_compose_file() {
  case "$DB_PROVIDER" in
    sqlite)      echo "docker-compose.yml" ;;
    mysql)       echo "docker-compose.mysql.yml" ;;
    postgresql)  echo "docker-compose.postgresql.yml" ;;
    mongodb)     echo "docker-compose.mongodb.yml" ;;
    mssql)       echo "docker-compose.mssql.yml" ;;
    *)           echo "docker-compose.yml" ;;
  esac
}

# ─── Install Database Client (bare-metal) ────────────
install_db_client() {
  if $USE_DOCKER || [[ "$DB_PROVIDER" == "sqlite" ]]; then
    return 0
  fi

  step "Installing database client tools"

  case "$DB_PROVIDER" in
    mysql)
      case "$PKG_MANAGER" in
        apt-get) apt-get install -y -qq mysql-client > /dev/null 2>&1 || warn "mysql-client install failed" ;;
        dnf)     dnf install -y -q mysql > /dev/null 2>&1 || warn "mysql install failed" ;;
        yum)     yum install -y -q mysql > /dev/null 2>&1 || warn "mysql install failed" ;;
      esac
      ok "MySQL client installed"
      ;;
    postgresql)
      case "$PKG_MANAGER" in
        apt-get) apt-get install -y -qq postgresql-client > /dev/null 2>&1 || warn "postgresql-client install failed" ;;
        dnf)     dnf install -y -q postgresql > /dev/null 2>&1 || warn "postgresql install failed" ;;
        yum)     yum install -y -q postgresql > /dev/null 2>&1 || warn "postgresql install failed" ;;
      esac
      ok "PostgreSQL client installed"
      ;;
    mongodb)
      # Install mongosh
      if command -v mongosh &>/dev/null; then
        ok "mongosh already installed"
        return
      fi
      case "$PKG_MANAGER" in
        apt-get)
          if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            curl -fsSL "https://www.mongodb.org/static/pgp/server-7.0.asc" | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null || true
            echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/${ID} ${VERSION_CODENAME:-jammy}/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null 2>&1 || true
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -q mongodb-mongosh > /dev/null 2>&1 || warn "mongosh install failed — install manually"
          fi
          ;;
        dnf|yum)
          curl -fsSL "https://www.mongodb.org/static/pgp/server-7.0.asc" | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null || true
          echo -e "[mongodb-org-7.0]\nname=MongoDB Repository\nbaseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/7.0/x86_64/\ngpgcheck=1\nenabled=1\ngpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc" | tee /etc/yum.repos.d/mongodb-org-7.0.repo > /dev/null 2>&1 || true
          $PKG_MANAGER install -y -q mongodb-mongosh > /dev/null 2>&1 || warn "mongosh install failed — install manually"
          ;;
      esac
      ok "MongoDB client (mongosh) installed"
      ;;
    mssql)
      # Install mssql-tools18
      if command -v sqlcmd &>/dev/null; then
        ok "mssql-tools already installed"
        return
      fi
      case "$PKG_MANAGER" in
        apt-get)
          if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg 2>/dev/null || true
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/${VERSION_ID:-22.04}/prod jammy main" | tee /etc/apt/sources.list.d/mssql-release.list > /dev/null 2>&1 || true
            apt-get update -qq 2>/dev/null || true
            ACCEPT_EULA=Y apt-get install -y -q mssql-tools18 unixodbc-dev > /dev/null 2>&1 || warn "mssql-tools18 install failed — see: https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools"
            ln -sf /opt/mssql-tools18/bin/sqlcmd /usr/local/bin/sqlcmd 2>/dev/null || true
          fi
          ;;
        dnf|yum)
          curl -fsSL https://packages.microsoft.com/config/rhel/9/prod.repo | tee /etc/yum.repos.d/mssql-release.repo > /dev/null 2>&1 || true
          ACCEPT_EULA=Y $PKG_MANAGER install -y -q mssql-tools18 unixODBC-devel > /dev/null 2>&1 || warn "mssql-tools18 install failed"
          ln -sf /opt/mssql-tools18/bin/sqlcmd /usr/local/bin/sqlcmd 2>/dev/null || true
          ;;
      esac
      ok "SQL Server tools (mssql-tools18) installed"
      ;;
  esac
}

# ─── Configure Database ──────────────────────────────
configure_database() {
  step "Configuring database ($DB_PROVIDER)"
  cd "$INSTALL_DIR"

  case "$DB_PROVIDER" in
    sqlite)
      _configure_sqlite
      ;;
    mysql)
      _configure_mysql
      ;;
    postgresql)
      _configure_postgresql
      ;;
    mongodb)
      _configure_mongodb
      ;;
    mssql)
      _configure_mssql
      ;;
    *)
      warn "Unknown database provider '$DB_PROVIDER' — falling back to SQLite"
      DB_PROVIDER="sqlite"
      _configure_sqlite
      ;;
  esac
}

_configure_sqlite() {
  if ! $DEV_MODE; then
    mkdir -p "$DATA_DIR"
    export DATABASE_URL="file:$DATA_DIR/cbup.db"

    cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="file:$DATA_DIR/cbup.db"
DATABASE_PROVIDER="sqlite"
NODE_ENV=production
PORT=$PORT
ENV
  else
    mkdir -p "$INSTALL_DIR/db"
    export DATABASE_URL="file:$INSTALL_DIR/db/custom.db"

    cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="file:./db/custom.db"
DATABASE_PROVIDER="sqlite"
NODE_ENV=development
PORT=$PORT
ENV
  fi

  info "Pushing database schema (SQLite)..."
  bun run db:push 2>&1 | tail -5

  if $DEV_MODE; then
    ok "SQLite database initialized at $INSTALL_DIR/db/custom.db"
  else
    ok "SQLite database initialized at $DATA_DIR/cbup.db"
  fi
}

_configure_mysql() {
  local db_host="localhost"
  local db_port="3306"
  local db_user="cbup"
  local db_pass="cbup_secure_2025"
  local db_name="cbup"

  if $USE_DOCKER; then
    # In Docker mode, the DB host is the service name
    db_host="mysql"
    info "MySQL will be provided via Docker Compose (service: mysql)"
    # Wait for MySQL container to be ready (it will be started by docker compose)
    # We just set up the env vars; the container connection happens at runtime
  else
    # Bare metal — install client
    install_db_client

    # Prompt for connection details or use defaults
    if ! $NONINTERACTIVE; then
      db_host=$(ask "MySQL host" "$db_host")
      db_port=$(ask "MySQL port" "$db_port")
      db_user=$(ask "MySQL user" "$db_user")
      db_pass=$(ask "MySQL password" "$db_pass")
      db_name=$(ask "MySQL database name" "$db_name")
    fi

    # Create database and user
    info "Creating MySQL database and user..."
    if command -v mysql &>/dev/null; then
      mysql -h "$db_host" -P "$db_port" -u root \
        -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
            CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_pass}';
            GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
            FLUSH PRIVILEGES;" 2>&1 \
        || warn "Could not create MySQL database/user automatically — please create them manually"
    else
      warn "mysql client not found — please create database '${db_name}' and user '${db_user}' manually"
    fi
  fi

  local db_url="mysql://${db_user}:${db_pass}@${db_host}:${db_port}/${db_name}"
  export DATABASE_URL="$db_url"

  # Write .env
  cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="${db_url}"
DATABASE_PROVIDER="mysql"
NODE_ENV=production
PORT=$PORT
ENV

  # Set up Prisma schema for MySQL
  if [[ -f "$INSTALL_DIR/prisma/schema.mysql.prisma" ]]; then
    info "Applying MySQL Prisma schema..."
    cp "$INSTALL_DIR/prisma/schema.mysql.prisma" "$INSTALL_DIR/prisma/schema.prisma"
  else
    warn "schema.mysql.prisma not found — using default schema (may need manual adjustment)"
  fi

  if ! $USE_DOCKER; then
    info "Generating Prisma client (MySQL)..."
    bunx prisma generate 2>&1 | tail -3
    info "Pushing database schema (MySQL)..."
    bunx prisma db push 2>&1 | tail -5
  fi

  ok "MySQL configured: ${db_user}@${db_host}:${db_port}/${db_name}"
}

_configure_postgresql() {
  local db_host="localhost"
  local db_port="5432"
  local db_user="cbup"
  local db_pass="cbup_secure_2025"
  local db_name="cbup"

  if $USE_DOCKER; then
    db_host="postgresql"
    info "PostgreSQL will be provided via Docker Compose (service: postgresql)"
  else
    install_db_client

    if ! $NONINTERACTIVE; then
      db_host=$(ask "PostgreSQL host" "$db_host")
      db_port=$(ask "PostgreSQL port" "$db_port")
      db_user=$(ask "PostgreSQL user" "$db_user")
      db_pass=$(ask "PostgreSQL password" "$db_pass")
      db_name=$(ask "PostgreSQL database name" "$db_name")
    fi

    # Create database and user
    info "Creating PostgreSQL database and user..."
    if command -v psql &>/dev/null; then
      sudo -u postgres psql -c "DO \$\$BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
          CREATE ROLE ${db_user} WITH LOGIN PASSWORD '${db_pass}';
        END IF;
      END\$\$;
      SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user}'
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec" 2>&1 \
        || warn "Could not create PostgreSQL database/user automatically — please create them manually"
    else
      warn "psql client not found — please create database '${db_name}' and user '${db_user}' manually"
    fi
  fi

  local db_url="postgresql://${db_user}:${db_pass}@${db_host}:${db_port}/${db_name}"
  export DATABASE_URL="$db_url"

  cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="${db_url}"
DATABASE_PROVIDER="postgresql"
NODE_ENV=production
PORT=$PORT
ENV

  if [[ -f "$INSTALL_DIR/prisma/schema.postgresql.prisma" ]]; then
    info "Applying PostgreSQL Prisma schema..."
    cp "$INSTALL_DIR/prisma/schema.postgresql.prisma" "$INSTALL_DIR/prisma/schema.prisma"
  else
    warn "schema.postgresql.prisma not found — using default schema (may need manual adjustment)"
  fi

  if ! $USE_DOCKER; then
    info "Generating Prisma client (PostgreSQL)..."
    bunx prisma generate 2>&1 | tail -3
    info "Pushing database schema (PostgreSQL)..."
    bunx prisma db push 2>&1 | tail -5
  fi

  ok "PostgreSQL configured: ${db_user}@${db_host}:${db_port}/${db_name}"
}

_configure_mongodb() {
  local db_host="localhost"
  local db_port="27017"
  local db_user="cbup"
  local db_pass="cbup_secure_2025"
  local db_name="cbup"

  if $USE_DOCKER; then
    db_host="mongodb"
    info "MongoDB will be provided via Docker Compose (service: mongodb)"
  else
    install_db_client

    if ! $NONINTERACTIVE; then
      db_host=$(ask "MongoDB host" "$db_host")
      db_port=$(ask "MongoDB port" "$db_port")
      db_user=$(ask "MongoDB user (leave empty for no auth)" "$db_user")
      db_pass=$(ask "MongoDB password (leave empty for no auth)" "$db_pass")
      db_name=$(ask "MongoDB database name" "$db_name")
    fi

    # Create user
    if command -v mongosh &>/dev/null; then
      info "Creating MongoDB user..."
      mongosh "mongodb://${db_host}:${db_port}/${db_name}" --quiet --eval "
        try {
          db.createUser({
            user: '${db_user}',
            pwd: '${db_pass}',
            roles: [{role: 'readWrite', db: '${db_name}'}]
          });
          print('User created successfully');
        } catch(e) {
          if (e.codeName === 'UserAlreadyExists') print('User already exists');
          else print('Warning: ' + e.message);
        }
      " 2>&1 || warn "Could not create MongoDB user automatically — please create manually"
    else
      warn "mongosh not found — please create MongoDB user '${db_user}' manually"
    fi
  fi

  # Build connection URL
  local db_url
  if [[ -n "$db_user" && -n "$db_pass" ]]; then
    db_url="mongodb://${db_user}:${db_pass}@${db_host}:${db_port}/${db_name}"
  else
    db_url="mongodb://${db_host}:${db_port}/${db_name}"
  fi

  export DATABASE_URL="$db_url"

  cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="${db_url}"
DATABASE_PROVIDER="mongodb"
NODE_ENV=production
PORT=$PORT
ENV

  info "MongoDB does not use Prisma — skipping schema push"

  if ! $USE_DOCKER && command -v mongosh &>/dev/null; then
    info "Creating MongoDB indexes..."
    mongosh "$db_url" --quiet --eval "
      db.briefs.createIndex({ createdAt: -1 });
      db.briefs.createIndex({ status: 1 });
      db.briefs.createIndex({ priority: 1 });
      db.users.createIndex({ email: 1 }, { unique: true });
    " 2>&1 || warn "Could not create indexes automatically"
  fi

  ok "MongoDB configured: ${db_user}@${db_host}:${db_port}/${db_name}"
}

_configure_mssql() {
  local db_host="localhost"
  local db_port="1433"
  local db_user="sa"
  local db_pass="Strong_Passw0rd_2025"
  local db_name="cbup"

  if $USE_DOCKER; then
    db_host="mssql"
    info "SQL Server will be provided via Docker Compose (service: mssql)"
  else
    # SQL Server on Linux requires manual setup
    warn "SQL Server on Linux requires manual installation and configuration."
    warn "See: https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-overview"

    if ! $NONINTERACTIVE; then
      db_host=$(ask "SQL Server host" "$db_host")
      db_port=$(ask "SQL Server port" "$db_port")
      db_user=$(ask "SQL Server user" "$db_user")
      db_pass=$(ask "SQL Server password" "$db_pass")
      db_name=$(ask "SQL Server database name" "$db_name")
    fi

    # Try to create database if sqlcmd is available
    if command -v sqlcmd &>/dev/null; then
      info "Creating SQL Server database..."
      sqlcmd -S "$db_host,$db_port" -U "$db_user" -P "$db_pass" -Q "
        IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '${db_name}')
        BEGIN
          CREATE DATABASE [${db_name}];
        END;
      " 2>&1 || warn "Could not create database automatically — please create manually"
    else
      warn "sqlcmd not found — please create database '${db_name}' manually"
    fi
  fi

  local db_url="mssql://${db_user}:${db_pass}@${db_host}:${db_port}/${db_name}"
  export DATABASE_URL="$db_url"

  cat > "$INSTALL_DIR/.env" << ENV
DATABASE_URL="${db_url}"
DATABASE_PROVIDER="mssql"
NODE_ENV=production
PORT=$PORT
ENV

  if [[ -f "$INSTALL_DIR/prisma/schema.mssql.prisma" ]]; then
    info "Applying SQL Server Prisma schema..."
    cp "$INSTALL_DIR/prisma/schema.mssql.prisma" "$INSTALL_DIR/prisma/schema.prisma"
  else
    warn "schema.mssql.prisma not found — using default schema (may need manual adjustment)"
  fi

  if ! $USE_DOCKER && command -v sqlcmd &>/dev/null; then
    info "Generating Prisma client (SQL Server)..."
    bunx prisma generate 2>&1 | tail -3
    info "Pushing database schema (SQL Server)..."
    bunx prisma db push 2>&1 | tail -5
  fi

  ok "SQL Server configured: ${db_user}@${db_host}:${db_port}/${db_name}"
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

  if $IS_WSL; then info "WSL environment detected — systemd support: $HAS_SYSTEMD"; fi
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

  # Use the repo's Dockerfile and the correct compose file
  info "Preparing Docker build files..."

  local compose_file
  compose_file=$(get_compose_file)

  # Ensure app files are in place first
  if [[ ! -f "$INSTALL_DIR/Dockerfile" ]]; then
    warn "Dockerfile not found in $INSTALL_DIR — copying from repo"
  fi

  # If the specific compose file doesn't exist, generate a default one
  if [[ ! -f "$INSTALL_DIR/$compose_file" ]]; then
    if [[ "$compose_file" == "docker-compose.yml" ]]; then
      warn "$compose_file not found in $INSTALL_DIR — generating for compatibility..."
      cat > "$INSTALL_DIR/$compose_file" << YML
services:
  cbup:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: cyber-brief-up
    restart: unless-stopped
    ports:
      - "${PORT:-3000}:3000"
    volumes:
      - cbup-data:/app/data
      - cbup-logs:/app/logs
    environment:
      - DATABASE_URL=file:/app/data/cbup.db
      - DATABASE_PROVIDER=sqlite
      - NODE_ENV=production
      - PORT=3000
      - HOSTNAME=0.0.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
      start_interval: 5s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 128M
          cpus: '0.25'
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  cbup-data:
    driver: local
    name: cbup-data
  cbup-logs:
    driver: local
    name: cbup-logs
YML
    else
      warn "$compose_file not found in $INSTALL_DIR — the installer expects this file in the repo"
      warn "Falling back to docker-compose.yml..."
      compose_file="docker-compose.yml"
      if [[ ! -f "$INSTALL_DIR/$compose_file" ]]; then
        cat > "$INSTALL_DIR/$compose_file" << YML
services:
  cbup:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: cyber-brief-up
    restart: unless-stopped
    ports:
      - "${PORT:-3000}:3000"
    volumes:
      - cbup-data:/app/data
      - cbup-logs:/app/logs
    environment:
      - DATABASE_URL=file:/app/data/cbup.db
      - DATABASE_PROVIDER=sqlite
      - NODE_ENV=production
      - PORT=3000
      - HOSTNAME=0.0.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
      start_interval: 5s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 128M
          cpus: '0.25'
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  cbup-data:
    driver: local
    name: cbup-data
  cbup-logs:
    driver: local
    name: cbup-logs
YML
      fi
    fi
  fi

  # Build and start using the correct compose file
  cd "$INSTALL_DIR"
  info "Building CBUP Docker image (this may take a few minutes)..."
  info "Using multi-stage Dockerfile with Bun runtime and Prisma..."
  info "Compose file: $compose_file | Database: $DB_PROVIDER"
  docker compose -f "$compose_file" build 2>&1 | tail -10
  info "Starting CBUP container..."
  docker compose -f "$compose_file" up -d 2>&1

  # Determine DB container name for health checks
  case "$DB_PROVIDER" in
    mysql)       DB_CONTAINER="cbup-mysql" ;;
    postgresql)  DB_CONTAINER="cbup-postgresql" ;;
    mongodb)     DB_CONTAINER="cbup-mongodb" ;;
    mssql)       DB_CONTAINER="cbup-mssql" ;;
  esac

  # Wait for health check
  info "Waiting for container to become healthy..."
  local retries=0
  while [[ $retries -lt 30 ]]; do
    if docker ps --format '{{.Status}}' --filter name=cyber-brief-up 2>/dev/null | grep -q "healthy"; then
      ok "CBUP container is healthy!"
      break
    fi
    if docker ps --filter name=cyber-brief-up --format '{{.Status}}' 2>/dev/null | grep -qi "unhealthy\|exited"; then
      error "Container health check failed. Check logs:"
      error "  docker logs cyber-brief-up"
      docker logs cyber-brief-up 2>&1 | tail -20
      return 1
    fi
    sleep 2
    ((retries++))
  done

  if [[ $retries -eq 30 ]]; then
    warn "Health check not yet passing (container may still be starting)"
    warn "Check status with: docker compose -f $compose_file ps"
  fi

  ok "CBUP is running in Docker on port $PORT (database: $DB_PROVIDER)"

  # Show database admin panel URL if applicable
  case "$DB_PROVIDER" in
    mysql)
      info "MySQL admin panel: phpMyAdmin should be accessible (check docker-compose.mysql.yml)"
      ;;
    postgresql)
      info "PostgreSQL admin panel: pgAdmin should be accessible (check docker-compose.postgresql.yml)"
      ;;
    mongodb)
      info "MongoDB admin panel: mongo-express should be accessible (check docker-compose.mongodb.yml)"
      ;;
  esac
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
  configure_database
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

  # Determine DATABASE_URL for systemd service
  local svc_db_url
  if [[ "$DB_PROVIDER" == "sqlite" ]]; then
    svc_db_url="file:$DATA_DIR/cbup.db"
  else
    # Read from .env
    svc_db_url=$(grep -E "^DATABASE_URL=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "file:$DATA_DIR/cbup.db")
    svc_db_url="${svc_db_url:-file:$DATA_DIR/cbup.db}"
  fi

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
Environment=DATABASE_PROVIDER=$DB_PROVIDER
Environment=DATABASE_URL=$svc_db_url
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
    local compose_file
    compose_file=$(get_compose_file)
    if [[ -f "$compose_file" ]]; then
      docker compose -f "$compose_file" up -d 2>&1 | tail -3
    else
      docker compose up -d 2>&1 | tail -3
    fi
    return
  fi

  if ! $HAS_SYSTEMD; then
    # Read DATABASE_URL from .env for manual start
    local env_url
    env_url=""
    if [[ -f "$INSTALL_DIR/.env" ]]; then
      env_url=$(grep -E "^DATABASE_URL=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
    fi
    if [[ -z "$env_url" ]]; then
      env_url="file:$DATA_DIR/cbup.db"
    fi
    warn "No systemd — start CBUP manually:"
    warn "  cd $INSTALL_DIR && DATABASE_URL=\"$env_url\" NODE_ENV=production PORT=$PORT bun run start"
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

# Read config from .env if available
DB_PROVIDER="sqlite"
DATABASE_URL=""
if [[ -f "$INSTALL_DIR/.env" ]]; then
  PORT=$(grep -E "^PORT=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "3000")
  PORT="${PORT:-3000}"
  DB_PROVIDER=$(grep -E "^DATABASE_PROVIDER=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "sqlite")
  DB_PROVIDER="${DB_PROVIDER:-sqlite}"
  DATABASE_URL=$(grep -E "^DATABASE_URL=" "$INSTALL_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' || echo "")
fi

# Helper: mask password in URL
mask_password() {
  local url="$1"
  # Replace password between : and @ with ****
  echo "$url" | sed -E 's/:([^:@]{1,})@/:****@/'
}

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
  db-info            Show database details and statistics
  shell              Open a shell in the app directory
  doctor             Run diagnostics checks
  uninstall          Remove CBUP completely

${BOLD}Examples:${NC}
  cbup start
  cbup logs 100
  cbup update
  cbup backup
  cbup db-info
  cbup doctor
HELP
}

cmd_start() {
  echo -e "${CYAN}[CBUP]${NC} Starting service..."

  # Docker mode — find compose file
  local compose_file=""
  if [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && command -v docker &>/dev/null; then
    compose_file="docker-compose.yml"
  fi
  # Check for DB-specific compose files
  for f in docker-compose.mysql.yml docker-compose.postgresql.yml docker-compose.mongodb.yml docker-compose.mssql.yml; do
    if [[ -f "$INSTALL_DIR/$f" ]] && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "cbup-mysql\|cbup-postgresql\|cbup-mongodb\|cbup-mssql"; then
      compose_file="$f"
      break
    fi
  done

  if [[ -n "$compose_file" ]] && command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
      cd "$INSTALL_DIR" && docker compose -f "$compose_file" up -d 2>&1 | tail -3
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

  # Docker — try DB-specific compose files first
  local compose_file=""
  for f in docker-compose.mysql.yml docker-compose.postgresql.yml docker-compose.mongodb.yml docker-compose.mssql.yml docker-compose.yml; do
    if [[ -f "$INSTALL_DIR/$f" ]] && command -v docker &>/dev/null; then
      compose_file="$f"
      break
    fi
  done

  if [[ -n "$compose_file" ]] && command -v docker &>/dev/null; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q cyber-brief-up; then
      cd "$INSTALL_DIR" && docker compose -f "$compose_file" down 2>&1
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
  echo -e "  Database:    $DB_PROVIDER"
  if [[ -n "$DATABASE_URL" ]]; then
    echo -e "  Connection:  $(mask_password "$DATABASE_URL")"
  fi

  # SQLite file size
  if [[ "$DB_PROVIDER" == "sqlite" ]]; then
    local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
    if [[ -f "$db_file" ]]; then
      DB_SIZE=$(du -h "$db_file" | cut -f1)
      echo -e "  DB File:     ${GREEN}OK${NC} ($DB_SIZE)"
    elif [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
      DB_SIZE=$(du -h "$INSTALL_DIR/db/custom.db" | cut -f1)
      echo -e "  DB File:     ${GREEN}OK (dev)${NC} ($DB_SIZE)"
    else
      echo -e "  DB File:     ${YELLOW}Not found${NC}"
    fi
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
    LAST_BACKUP=$(ls -t "${BACKUP_DIR:-/var/backups/cbup}"/cbup-backup-*.* 2>/dev/null | head -1)
    if [[ -n "$LAST_BACKUP" ]]; then
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

  # Push schema only for Prisma-supported databases
  if [[ "$DB_PROVIDER" != "mongodb" ]]; then
    echo -e "${CYAN}[CBUP]${NC} Pushing database schema..."
    if [[ -f .env ]]; then
      set -a; source .env; set +a
    fi
    bun run db:push 2>&1 | tail -3
  fi

  echo -e "${CYAN}[CBUP]${NC} Building production bundle..."
  bun run build 2>&1 | tail -5

  cmd_restart
  echo -e "${GREEN}[CBUP]${NC} Update complete!"
}

cmd_backup() {
  mkdir -p "${BACKUP_DIR:-/var/backups/cbup}"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  case "$DB_PROVIDER" in
    sqlite)
      local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.db"
      local db_file=""
      if [[ -f "${DATA_DIR:-/var/lib/cbup}/cbup.db" ]]; then
        db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
      elif [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
        db_file="$INSTALL_DIR/db/custom.db"
      fi

      if [[ -n "$db_file" ]]; then
        cp "$db_file" "$backup_file"
        gzip -f "$backup_file"
        echo -e "${GREEN}[CBUP]${NC} SQLite backup created: ${backup_file}.gz ($(du -h "${backup_file}.gz" | cut -f1))"
      else
        echo -e "${YELLOW}[CBUP]${NC} No SQLite database to backup."
      fi
      ;;

    mysql)
      local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.sql.gz"
      if command -v mysqldump &>/dev/null; then
        # Extract connection details from DATABASE_URL
        local my_url="${DATABASE_URL:-mysql://cbup:cbup_secure_2025@localhost:3306/cbup}"
        my_url="${my_url#mysql://}"
        local my_user="${my_url%%:*}"
        local my_pass="${my_url#*:}"; my_pass="${my_pass%%@*}"
        local my_host_port="${my_url#*@}"; my_host_port="${my_host_port%%/*}"
        local my_db="${my_url##*/}"

        mysqldump -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" "$my_db" 2>/dev/null | gzip > "$backup_file" \
          && echo -e "${GREEN}[CBUP]${NC} MySQL backup created: ${backup_file} ($(du -h "$backup_file" | cut -f1))" \
          || echo -e "${RED}[CBUP]${NC} MySQL backup failed — check connection settings"
      else
        echo -e "${RED}[CBUP]${NC} mysqldump not found. Install mysql-client."
      fi
      ;;

    postgresql)
      local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.sql.gz"
      if command -v pg_dump &>/dev/null; then
        local pg_url="${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}"
        pg_dump "$pg_url" 2>/dev/null | gzip > "$backup_file" \
          && echo -e "${GREEN}[CBUP]${NC} PostgreSQL backup created: ${backup_file} ($(du -h "$backup_file" | cut -f1))" \
          || echo -e "${RED}[CBUP]${NC} PostgreSQL backup failed — check connection settings"
      else
        echo -e "${RED}[CBUP]${NC} pg_dump not found. Install postgresql-client."
      fi
      ;;

    mongodb)
      local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.mongodump.gz"
      if command -v mongodump &>/dev/null; then
        local mongo_url="${DATABASE_URL:-mongodb://cbup:cbup_secure_2025@localhost:27017/cbup}"
        local backup_dir="${BACKUP_DIR:-/var/backups/cbup}/cbup-mongodump-${timestamp}"
        mongodump --uri="$mongo_url" --out="$backup_dir" 2>/dev/null \
          && tar -czf "$backup_file" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")" 2>/dev/null \
          && rm -rf "$backup_dir" \
          && echo -e "${GREEN}[CBUP]${NC} MongoDB backup created: ${backup_file} ($(du -h "$backup_file" | cut -f1))" \
          || { rm -rf "$backup_dir" 2>/dev/null; echo -e "${RED}[CBUP]${NC} MongoDB backup failed — check connection settings"; }
      else
        echo -e "${RED}[CBUP]${NC} mongodump not found. Install mongosh / mongodb-tools."
      fi
      ;;

    mssql)
      local backup_file="${BACKUP_DIR:-/var/backups/cbup}/cbup-backup-${timestamp}.sql"
      if command -v sqlcmd &>/dev/null; then
        echo -e "${YELLOW}[CBUP]${NC} SQL Server backup: consider using native BACKUP DATABASE command"
        echo -e "${YELLOW}[CBUP]${NC} sqlcmd -S host -U sa -P pass -Q \"BACKUP DATABASE [cbup] TO DISK='${backup_file}'\""
      else
        echo -e "${RED}[CBUP]${NC} sqlcmd not found. Install mssql-tools18."
      fi
      ;;

    *)
      echo -e "${YELLOW}[CBUP]${NC} Unknown database provider '$DB_PROVIDER' — cannot backup"
      ;;
  esac
  
  # Keep only last 30 backups
  cd "${BACKUP_DIR:-/var/backups/cbup}" 2>/dev/null && ls -t cbup-backup-* 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true
}

cmd_restore() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    echo -e "${RED}[CBUP]${NC} Usage: cbup restore <backup-file>"
    echo -e "${YELLOW}[CBUP]${NC} Available backups:"
    ls -lht "${BACKUP_DIR:-/var/backups/cbup}"/cbup-backup-* 2>/dev/null || echo "  (none found)"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo -e "${RED}[CBUP]${NC} File not found: $file"
    return 1
  fi

  cmd_stop
  
  # Backup current before restoring
  cmd_backup

  case "$DB_PROVIDER" in
    sqlite)
      local target_db="${DATA_DIR:-/var/lib/cbup}/cbup.db"
      if [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
        target_db="$INSTALL_DIR/db/custom.db"
      fi
      mkdir -p "$(dirname "$target_db")"

      if [[ "$file" == *.gz ]]; then
        gunzip -c "$file" > "$target_db"
      else
        cp "$file" "$target_db"
      fi
      ;;

    mysql)
      if command -v mysql &>/dev/null; then
        local my_url="${DATABASE_URL:-mysql://cbup:cbup_secure_2025@localhost:3306/cbup}"
        my_url="${my_url#mysql://}"
        local my_user="${my_url%%:*}"
        local my_pass="${my_url#*:}"; my_pass="${my_pass%%@*}"
        local my_host_port="${my_url#*@}"; my_host_port="${my_host_port%%/*}"
        local my_db="${my_url##*/}"

        if [[ "$file" == *.gz ]]; then
          gunzip -c "$file" | mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" "$my_db" 2>&1
        else
          mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" "$my_db" < "$file" 2>&1
        fi
        echo -e "${GREEN}[CBUP]${NC} MySQL restore completed."
      else
        echo -e "${RED}[CBUP]${NC} mysql client not found."
      fi
      ;;

    postgresql)
      if command -v psql &>/dev/null; then
        local pg_url="${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}"
        if [[ "$file" == *.gz ]]; then
          gunzip -c "$file" | psql "$pg_url" 2>&1
        else
          psql "$pg_url" < "$file" 2>&1
        fi
        echo -e "${GREEN}[CBUP]${NC} PostgreSQL restore completed."
      else
        echo -e "${RED}[CBUP]${NC} psql client not found."
      fi
      ;;

    mongodb)
      if command -v mongorestore &>/dev/null; then
        local mongo_url="${DATABASE_URL:-mongodb://cbup:cbup_secure_2025@localhost:27017/cbup}"
        if [[ "$file" == *.gz ]]; then
          local tmp_dir
          tmp_dir=$(mktemp -d)
          tar -xzf "$file" -C "$tmp_dir" 2>/dev/null
          mongorestore --uri="$mongo_url" --drop "$tmp_dir"/ 2>/dev/null
          rm -rf "$tmp_dir"
        else
          mongorestore --uri="$mongo_url" --drop "$file" 2>/dev/null
        fi
        echo -e "${GREEN}[CBUP]${NC} MongoDB restore completed."
      else
        echo -e "${RED}[CBUP]${NC} mongorestore not found."
      fi
      ;;

    mssql)
      echo -e "${YELLOW}[CBUP]${NC} SQL Server restore: use sqlcmd or native restore command manually"
      ;;

    *)
      echo -e "${RED}[CBUP]${NC} Unknown database provider '$DB_PROVIDER'"
      ;;
  esac

  cmd_start
  echo -e "${GREEN}[CBUP]${NC} Restore from $file completed."
}

cmd_reset_db() {
  echo -e "${RED}${BOLD}[WARNING]${NC} This will DELETE all data and reset the database!"
  read -rp "Type 'RESET' to confirm: " confirm
  if [[ "$confirm" != "RESET" ]]; then
    echo "Cancelled."
    return
  fi

  cmd_stop

  case "$DB_PROVIDER" in
    sqlite)
      local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
      if [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
        db_file="$INSTALL_DIR/db/custom.db"
      fi
      rm -f "$db_file"
      ;;
    mysql)
      if command -v mysql &>/dev/null; then
        local my_url="${DATABASE_URL:-mysql://cbup:cbup_secure_2025@localhost:3306/cbup}"
        my_url="${my_url#mysql://}"
        local my_user="${my_url%%:*}"
        local my_pass="${my_url#*:}"; my_pass="${my_pass%%@*}"
        local my_host_port="${my_url#*@}"; my_host_port="${my_host_port%%/*}"
        local my_db="${my_url##*/}"
        mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" -e "DROP DATABASE IF EXISTS \`$my_db\`; CREATE DATABASE \`$my_db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1
      fi
      ;;
    postgresql)
      if command -v psql &>/dev/null; then
        local pg_url="${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}"
        psql "$pg_url" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>&1
      fi
      ;;
    mongodb)
      if command -v mongosh &>/dev/null; then
        local mongo_url="${DATABASE_URL:-mongodb://cbup:cbup_secure_2025@localhost:27017/cbup}"
        mongosh "$mongo_url" --quiet --eval "db.dropDatabase(); print('Dropped: ' + db.getName());" 2>&1
      fi
      ;;
    mssql)
      if command -v sqlcmd &>/dev/null; then
        echo -e "${YELLOW}[CBUP]${NC} For SQL Server, reset manually using sqlcmd"
      fi
      ;;
  esac

  cd "$INSTALL_DIR"
  if [[ -f .env ]]; then
    set -a; source .env; set +a
  fi

  if [[ "$DB_PROVIDER" != "mongodb" ]]; then
    bun run db:push 2>&1 | tail -3
  fi

  cmd_start
  echo -e "${GREEN}[CBUP]${NC} Database has been reset."
}

cmd_db_info() {
  echo -e "${BOLD}${CYAN}═══ CBUP Database Information ═══${NC}"
  echo ""

  echo -e "  Provider:      ${BOLD}$DB_PROVIDER${NC}"

  if [[ -n "$DATABASE_URL" ]]; then
    echo -e "  Connection:    $(mask_password "$DATABASE_URL")"
  else
    echo -e "  Connection:    ${YELLOW}Not configured${NC}"
  fi

  echo ""

  case "$DB_PROVIDER" in
    sqlite)
      local db_file="${DATA_DIR:-/var/lib/cbup}/cbup.db"
      if [[ -f "$INSTALL_DIR/db/custom.db" ]]; then
        db_file="$INSTALL_DIR/db/custom.db"
      fi
      if [[ -f "$db_file" ]]; then
        local db_size
        db_size=$(du -h "$db_file" | cut -f1)
        echo -e "  File:          $db_file"
        echo -e "  Size:          ${GREEN}$db_size${NC}"

        if command -v sqlite3 &>/dev/null; then
          echo ""
          echo -e "  ${BOLD}Tables:${NC}"
          sqlite3 "$db_file" ".tables" 2>/dev/null | tr ' ' '\n' | while read -r tbl; do
            if [[ -n "$tbl" ]]; then
              local count
              count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM \"$tbl\";" 2>/dev/null || echo "?")
              echo -e "    $tbl: ${GREEN}$count${NC} rows"
            fi
          done
        fi
      else
        echo -e "  ${YELLOW}No SQLite database file found${NC}"
      fi
      ;;

    mysql)
      if command -v mysql &>/dev/null; then
        local my_url="${DATABASE_URL:-mysql://cbup:cbup_secure_2025@localhost:3306/cbup}"
        my_url="${my_url#mysql://}"
        local my_user="${my_url%%:*}"
        local my_pass="${my_url#*:}"; my_pass="${my_pass%%@*}"
        local my_host_port="${my_url#*@}"; my_host_port="${my_host_port%%/*}"
        local my_db="${my_url##*/}"

        echo -e "  Host:          ${my_host_port%%:*}:${my_host_port##*:}"
        echo -e "  Database:      $my_db"
        echo -e "  User:          $my_user"
        echo ""

        # Check connectivity
        echo -n "  Connectivity:  "
        if mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" -e "SELECT 1" &>/dev/null; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
        fi

        echo ""
        echo -e "  ${BOLD}Tables:${NC}"
        mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" "$my_db" \
          -e "SELECT table_name AS 'Table', table_rows AS 'Rows', ROUND(data_length / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = '$my_db';" 2>/dev/null \
          || echo -e "    ${YELLOW}Could not query tables${NC}"

        # Database size
        echo ""
        local db_size
        db_size=$(mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" "$my_db" \
          -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = '$my_db';" 2>/dev/null | tail -1 || echo "?")
        echo -e "  Total Size:    ${GREEN}${db_size} MB${NC}"
      else
        echo -e "  ${YELLOW}mysql client not available${NC}"
      fi
      ;;

    postgresql)
      if command -v psql &>/dev/null; then
        echo ""

        echo -n "  Connectivity:  "
        if psql "${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}" -c "SELECT 1" &>/dev/null; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
        fi

        echo ""
        echo -e "  ${BOLD}Tables:${NC}"
        psql "${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}" \
          -c "SELECT schemaname||'.'||tablename AS \"Table\", n_live_tup AS \"Rows\", pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS \"Size\" FROM pg_stat_user_tables ORDER BY n_live_tup DESC;" 2>/dev/null \
          || echo -e "    ${YELLOW}Could not query tables${NC}"

        echo ""
        local db_size
        db_size=$(psql "${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}" \
          -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" 2>/dev/null | tr -d ' ' || echo "?")
        echo -e "  Total Size:    ${GREEN}${db_size}${NC}"
      else
        echo -e "  ${YELLOW}psql client not available${NC}"
      fi
      ;;

    mongodb)
      if command -v mongosh &>/dev/null; then
        local mongo_url="${DATABASE_URL:-mongodb://cbup:cbup_secure_2025@localhost:27017/cbup}"

        echo ""
        echo -n "  Connectivity:  "
        if mongosh "$mongo_url" --quiet --eval "db.runCommand({ping:1}).ok" 2>/dev/null | grep -q "1"; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
        fi

        echo ""
        echo -e "  ${BOLD}Collections:${NC}"
        mongosh "$mongo_url" --quiet --eval "
          db.getCollectionNames().forEach(function(c) {
            var count = db[c].countDocuments();
            print('    ' + c + ': ' + count + ' docs');
          });
        " 2>/dev/null || echo -e "    ${YELLOW}Could not query collections${NC}"

        echo ""
        local db_size
        db_size=$(mongosh "$mongo_url" --quiet --eval "
          var stats = db.stats();
          var sizeMB = (stats.dataSize / 1024 / 1024).toFixed(2);
          print(sizeMB + ' MB');
        " 2>/dev/null || echo "?")
        echo -e "  Total Size:    ${GREEN}${db_size}${NC}"
      else
        echo -e "  ${YELLOW}mongosh not available${NC}"
      fi
      ;;

    mssql)
      if command -v sqlcmd &>/dev/null; then
        echo ""
        echo -n "  Connectivity:  "
        if sqlcmd "${DATABASE_URL:-mssql://sa:Strong_Passw0rd_2025@localhost:1433/cbup}" -Q "SELECT 1" &>/dev/null; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
        fi
        echo ""
        echo -e "  ${BOLD}Tables:${NC}"
        echo -e "    Use sqlcmd to query tables manually"
      else
        echo -e "  ${YELLOW}sqlcmd not available${NC}"
      fi
      ;;

    *)
      echo -e "  ${YELLOW}Unknown database provider${NC}"
      ;;
  esac

  echo ""
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

  # Database provider
  echo -n "  DB Provider:  "
  echo -e "${BOLD}${DB_PROVIDER}${NC}"

  # Check database connectivity
  echo -n "  DB Connect:   "
  case "$DB_PROVIDER" in
    sqlite)
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
      ;;
    mysql)
      if command -v mysql &>/dev/null; then
        local my_url="${DATABASE_URL:-mysql://cbup:cbup_secure_2025@localhost:3306/cbup}"
        my_url="${my_url#mysql://}"
        local my_user="${my_url%%:*}"
        local my_pass="${my_url#*:}"; my_pass="${my_pass%%@*}"
        local my_host_port="${my_url#*@}"; my_host_port="${my_host_port%%/*}"
        local my_db="${my_url##*/}"
        if mysql -h "${my_host_port%%:*}" -P "${my_host_port##*:}" -u "$my_user" -p"$my_pass" -e "SELECT 1" &>/dev/null; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
          ((errors++))
        fi
      else
        echo -e "${RED}mysql client not found${NC}"
        ((errors++))
      fi
      ;;
    postgresql)
      if command -v psql &>/dev/null; then
        if psql "${DATABASE_URL:-postgresql://cbup:cbup_secure_2025@localhost:5432/cbup}" -c "SELECT 1" &>/dev/null; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
          ((errors++))
        fi
      else
        echo -e "${RED}psql client not found${NC}"
        ((errors++))
      fi
      ;;
    mongodb)
      if command -v mongosh &>/dev/null; then
        if mongosh "${DATABASE_URL:-mongodb://cbup:cbup_secure_2025@localhost:27017/cbup}" --quiet --eval "db.runCommand({ping:1}).ok" 2>/dev/null | grep -q "1"; then
          echo -e "${GREEN}Connected${NC}"
        else
          echo -e "${RED}Connection failed${NC}"
          ((errors++))
        fi
      else
        echo -e "${RED}mongosh not found${NC}"
        ((errors++))
      fi
      ;;
    mssql)
      if command -v sqlcmd &>/dev/null; then
        echo -e "${YELLOW}sqlcmd available — manual connectivity check needed${NC}"
      else
        echo -e "${RED}sqlcmd not found${NC}"
        ((errors++))
      fi
      ;;
  esac

  # Connection string (password masked)
  if [[ -n "$DATABASE_URL" ]]; then
    echo -e "  Connection:    $(mask_password "$DATABASE_URL")"
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

  # Docker — try all compose files
  for f in docker-compose.mysql.yml docker-compose.postgresql.yml docker-compose.mongodb.yml docker-compose.mssql.yml docker-compose.yml; do
    if [[ -f "$INSTALL_DIR/$f" ]] && command -v docker &>/dev/null; then
      cd "$INSTALL_DIR" && docker compose -f "$f" down -v 2>/dev/null || true
    fi
  done

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
  echo -e "${YELLOW}[CBUP]${NC} Database data was preserved if it was on a separate server."
  if [[ "$DB_PROVIDER" == "sqlite" ]]; then
    echo -e "${YELLOW}[CBUP]${NC} SQLite database at $DATA_DIR was preserved. Remove manually if desired:"
    echo -e "${YELLOW}[CBUP]${NC}   rm -rf $DATA_DIR"
  fi
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
  db-info)  cmd_db_info ;;
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
    # Stop Docker containers for all compose files
    for f in docker-compose.mysql.yml docker-compose.postgresql.yml docker-compose.mongodb.yml docker-compose.mssql.yml docker-compose.yml; do
      if [[ -f "$INSTALL_DIR/$f" ]] && command -v docker &>/dev/null; then
        cd "$INSTALL_DIR" && docker compose -f "$f" down -v 2>/dev/null || true
      fi
    done
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

  test_pass() { passed=$((passed + 1)); echo -e "  ${GREEN}✓ PASS${NC}: $1"; }
  test_fail() { failed=$((failed + 1)); echo -e "  ${RED}✗ FAIL${NC}: $1 — $2"; }
  test_skip() { skipped=$((skipped + 1)); echo -e "  ${YELLOW}⊘ SKIP${NC}: $1 — $2"; }

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
  echo -e "  ${BOLD}Database:${NC}    $DB_PROVIDER"

  if [[ "$DB_PROVIDER" != "sqlite" ]]; then
    echo -e "  ${BOLD}DB Connection:${NC} $(echo "$DATABASE_URL" | sed -E 's/:([^:@]{1,})@/:****@/')"
  fi

  if $IS_WSL; then
    echo ""
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
  echo -e "    cbup db-info    — Show database details"
  echo -e "    cbup doctor     — Run diagnostics"
  echo -e "    cbup --help     — All commands"
  echo ""

  if ! $DEV_MODE && ! $USE_DOCKER; then
    echo -e "  ${BOLD}Files:${NC}"
    echo -e "    App:        $INSTALL_DIR"
    if [[ "$DB_PROVIDER" == "sqlite" ]]; then
      echo -e "    Database:   $DATA_DIR/cbup.db"
    fi
    echo -e "    Logs:       $LOG_DIR/"
    echo -e "    Backups:    $BACKUP_DIR/"
    echo ""
  elif $DEV_MODE; then
    echo -e "  ${BOLD}Files:${NC}"
    echo -e "    App:        $INSTALL_DIR"
    if [[ "$DB_PROVIDER" == "sqlite" ]]; then
      echo -e "    Database:   $INSTALL_DIR/db/custom.db"
    fi
    echo ""
  fi

  if $USE_DOCKER; then
    local compose_file
    compose_file=$(get_compose_file)
    echo -e "  ${BOLD}Docker:${NC}"
    echo -e "    cd $INSTALL_DIR && docker compose -f $compose_file logs -f"
    echo ""
    case "$DB_PROVIDER" in
      mysql)
        echo -e "  ${BOLD}Database Admin:${NC} phpMyAdmin (check docker-compose.mysql.yml for port)"
        ;;
      postgresql)
        echo -e "  ${BOLD}Database Admin:${NC} pgAdmin (check docker-compose.postgresql.yml for port)"
        ;;
      mongodb)
        echo -e "  ${BOLD}Database Admin:${NC} mongo-express (check docker-compose.mongodb.yml for port)"
        ;;
    esac
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
      --db)
        case "${2:-}" in
          sqlite|mysql|postgresql|mongodb|mssql)
            DB_PROVIDER="$2"
            shift 2
            ;;
          *)
            die "Invalid database provider: ${2:-}. Use: sqlite, mysql, postgresql, mongodb, or mssql"
            ;;
        esac
        ;;
      --help|-h)      echo "Usage: $0 [--docker] [--dev] [--port N] [--db <sqlite|mysql|postgresql|mongodb|mssql>] [--yes] [--uninstall] [--test] [--branch X]"; exit 0 ;;
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

  # Select database before proceeding
  select_database

  if $USE_DOCKER; then
    info "Install mode: Docker (database: $DB_PROVIDER)"
    IS_NEW=true
    check_existing || IS_NEW=false
    # Clone/copy repo first so Dockerfile and docker-compose.yml are available
    clone_or_copy_repo $([[ "$IS_NEW" == "false" ]] && echo true || echo false)
    configure_database
    install_docker
    install_cli
  elif $DEV_MODE; then
    info "Install mode: Development (database: $DB_PROVIDER)"
    IS_NEW=true
    check_existing || IS_NEW=false
    install_prerequisites
    install_bun
    clone_or_copy_repo $([[ "$IS_NEW" == "false" ]] && echo true || echo false)
    install_dependencies
    install_db_client
    setup_database
    build_application
    start_service
    install_cli
  else
    info "Install mode: Bare Metal (database: $DB_PROVIDER)"
    IS_NEW=true
    check_existing || IS_NEW=false
    install_prerequisites
    install_bun
    clone_or_copy_repo $([[ "$IS_NEW" == "false" ]] && echo true || echo false)
    install_dependencies
    install_db_client
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
