#!/usr/bin/env bash
# =============================================================================
# CBUP Agent - Linux Endpoint Monitoring & EDR
# =============================================================================
# Comprehensive endpoint monitoring agent for the Cyber Brief Unified Platform (CBUP).
# Collects system metrics, performs EDR scanning, and communicates with the CBUP
# portal via a command-and-control (C2) protocol for centralized security management.
#
# Compatible with: Ubuntu 18.04+, Debian 10+
#
# Usage:
#   ./cbup-agent-linux.sh --server-url https://cbup.example.com --install
#   ./cbup-agent-linux.sh --server-url https://cbup.example.com --dev-mode
#   ./cbup-agent-linux.sh --uninstall
#
# Version:    2.0.0
# Author:     CBUP Security Engineering
# License:    Proprietary
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================
readonly AGENT_VERSION="2.0.0"
readonly AGENT_NAME="cbup-agent"
readonly INSTALL_DIR="/opt/cbup-agent"
readonly CONFIG_DIR="/etc/cbup-agent"
readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"
readonly LOG_DIR="/var/log/cbup-agent"
readonly LOG_FILE="${LOG_DIR}/agent.log"
readonly SERVICE_NAME="cbup-agent"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly MAX_LOG_SIZE_MB=50
readonly MAX_LOG_FILES=5
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5
readonly COMMAND_POLL_INTERVAL=15
readonly DEFAULT_INTERVAL=30
readonly DEFAULT_SCAN_INTERVAL=60

# Suspicious port signatures
readonly SUSPICIOUS_PORTS="1337 4444 5555 31337 1234 6666 6667 8888 9999 5556 32764 5985 445"

# Known suspicious process name patterns (grep -E)
readonly SUSPICIOUS_PROC_PATTERNS="mimikatz|nc\.exe|ncat|psexec|openssl.*-connect|wget.*http|curl.*http|certutil|bitsadmin|python.*-m http"

# Safe cron/autorun prefixes
readonly SAFE_AUTORUN_PREFIXES="^(/usr/bin/|^/usr/sbin/|^/usr/local/bin/|^/etc/|^/opt/)"

# =============================================================================
# RUNTIME STATE (global variables)
# =============================================================================
SHUTDOWN_REQUESTED=0
SERVER_URL=""
AGENT_ID=""
AUTH_TOKEN=""
TELEMETRY_INTERVAL=$DEFAULT_INTERVAL
SCAN_INTERVAL=$DEFAULT_SCAN_INTERVAL
DEV_MODE=0
LAST_HEARTBEAT_SUCCESS=0

# For disk I/O delta calculation
declare -A PREV_DISK_STATS=()
declare -A PREV_NET_STATS=()
PREV_STATS_TIME=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

usage() {
    cat <<'EOF'
CBUP Agent v2.0.0 - Linux Endpoint Monitoring & EDR

Usage:
  cbup-agent-linux.sh [OPTIONS]

Options:
  --server-url URL      CBUP Portal URL (required for registration)
  --install             Install agent as systemd service
  --uninstall           Uninstall agent service and remove files
  --interval SECONDS    Telemetry interval in seconds (default: 30, range: 5-300)
  --scan-interval MIN   EDR scan interval in minutes (default: 60, 0=disabled)
  --token TOKEN         Pre-authenticated registration token
  --dev-mode            Run in foreground with verbose output
  --help                Show this help message

Examples:
  ./cbup-agent-linux.sh --server-url https://cbup.example.com --install
  ./cbup-agent-linux.sh --server-url https://cbup.example.com --dev-mode --interval 10
  ./cbup-agent-linux.sh --uninstall
EOF
    exit 0
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local entry="[${timestamp}] [${level}] ${message}"

    # Console output in dev mode
    if [[ $DEV_MODE -eq 1 ]]; then
        case "$level" in
            ERROR) echo -e "\033[0;31m${entry}\033[0m" ;;
            WARN)  echo -e "\033[0;33m${entry}\033[0m" ;;
            DEBUG) echo -e "\033[0;36m${entry}\033[0m" ;;
            *)     echo -e "${entry}" ;;
        esac
    fi

    # File logging (always)
    echo "$entry" >> "$LOG_FILE" 2>/dev/null || true
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { log "DEBUG" "$@"; }

# =============================================================================
# LOG ROTATION
# =============================================================================

rotate_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return
    fi

    local log_size_mb
    log_size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)

    if [[ "$log_size_mb" -ge "$MAX_LOG_SIZE_MB" ]]; then
        local archive="${LOG_FILE}.$(date +%Y%m%d-%H%M%S).bak"
        mv "$LOG_FILE" "$archive" 2>/dev/null || true

        # Keep only the newest MAX_LOG_FILES archived logs
        local count
        count=$(ls -1 "${LOG_FILE}".*.bak 2>/dev/null | wc -l)
        if [[ "$count" -gt "$MAX_LOG_FILES" ]]; then
            ls -1t "${LOG_FILE}".*.bak 2>/dev/null | tail -n +"$((MAX_LOG_FILES + 1))" | xargs rm -f 2>/dev/null || true
        fi

        log_info "Rotated log file to ${archive}"
    fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

ensure_config_dir() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    chown root:root "$CONFIG_DIR" 2>/dev/null || true
    chown root:root "$LOG_DIR" 2>/dev/null || true
    chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
    chmod 640 "$LOG_FILE" 2>/dev/null || true
}

generate_agent_id() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            # Trim whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            case "$key" in
                SERVER_URL)       [[ -n "$value" && -z "$SERVER_URL" ]] && SERVER_URL="$value" ;;
                AGENT_ID)         [[ -n "$value" && -z "$AGENT_ID" ]] && AGENT_ID="$value" ;;
                AUTH_TOKEN)       [[ -n "$value" && -z "$AUTH_TOKEN" ]] && AUTH_TOKEN="$value" ;;
                TELEMETRY_INTERVAL) [[ -n "$value" ]] && TELEMETRY_INTERVAL="$value" ;;
                SCAN_INTERVAL)    [[ -n "$value" ]] && SCAN_INTERVAL="$value" ;;
                DEV_MODE)         [[ "$value" == "1" ]] && DEV_MODE=1 ;;
            esac
        done < "$CONFIG_FILE"
        log_debug "Loaded config from ${CONFIG_FILE}. AgentId=${AGENT_ID}"
    fi
}

save_config() {
    cat > "$CONFIG_FILE" <<EOF
# CBUP Agent Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# DO NOT EDIT MANUALLY unless you know what you are doing

SERVER_URL=${SERVER_URL}
AGENT_ID=${AGENT_ID}
AUTH_TOKEN=${AUTH_TOKEN}
TELEMETRY_INTERVAL=${TELEMETRY_INTERVAL}
SCAN_INTERVAL=${SCAN_INTERVAL}
DEV_MODE=${DEV_MODE}
EOF
    chmod 640 "$CONFIG_FILE"
    log_info "Configuration saved to ${CONFIG_FILE}"
}

# =============================================================================
# INSTALL / UNINSTALL
# =============================================================================

do_install() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Installation requires root privileges. Use: sudo $0 --server-url URL --install"
        exit 1
    fi

    if [[ -z "$SERVER_URL" ]]; then
        log_error "Server URL is required for installation. Use --server-url"
        exit 1
    fi

    log_info "Starting CBUP Agent installation..."

    # Create directories
    ensure_config_dir
    mkdir -p "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"

    # Copy agent script
    local script_source
    script_source="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    cp "$script_source" "${INSTALL_DIR}/cbup-agent.sh"
    chmod 750 "${INSTALL_DIR}/cbup-agent.sh"

    # Generate agent ID if not already set
    if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID=$(generate_agent_id)
    fi

    # Save configuration
    save_config

    # Create systemd service unit
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=CBUP Monitoring Agent - Endpoint Monitoring & EDR
Documentation=https://cbup.example.com/docs
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/cbup-agent.sh
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=300
StandardOutput=journal
StandardError=journal
WorkingDirectory=${INSTALL_DIR}
Environment=CBUP_CONFIG=${CONFIG_FILE}

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${LOG_DIR} ${CONFIG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        log_info "CBUP Agent installed and started successfully."
        log_info "  Agent ID: ${AGENT_ID}"
        log_info "  Service:  ${SERVICE_NAME}"
        log_info "  Log:      ${LOG_FILE}"
        log_info "  Config:   ${CONFIG_FILE}"
    else
        log_error "Service started but may not be running. Check: journalctl -u ${SERVICE_NAME} -f"
    fi
}

do_uninstall() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Uninstallation requires root privileges. Use: sudo $0 --uninstall"
        exit 1
    fi

    log_info "Starting CBUP Agent uninstallation..."

    # Stop and disable service
    if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
        systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
        systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    fi

    # Remove service file
    if [[ -f "$SERVICE_FILE" ]]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi

    # Remove installed files (keep config as backup)
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "${INSTALL_DIR}"
    fi

    # Remove logs
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "${LOG_DIR}"
    fi

    # Remove config
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "${CONFIG_DIR}"
    fi

    log_info "CBUP Agent uninstalled successfully."
}

# =============================================================================
# API COMMUNICATION
# =============================================================================

api_call() {
    local method="$1"
    local endpoint="$2"
    local body="${3:-}"

    if [[ -z "$SERVER_URL" ]]; then
        log_error "ServerUrl not configured. Cannot call API."
        return 1
    fi

    local url="${SERVER_URL%/}${endpoint}"
    local attempt=0

    while [[ $attempt -lt $MAX_RETRIES ]]; do
        attempt=$((attempt + 1))
        local http_code=""
        local response=""

        local tmpfile
        tmpfile=$(mktemp)

        if [[ -n "$body" ]]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "Content-Type: application/json" \
                -H "User-Agent: CBUP-Agent/${AGENT_VERSION} (Linux)" \
                -H "X-Agent-Id: ${AGENT_ID}" \
                -H "X-Agent-Version: ${AGENT_VERSION}" \
                ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"} \
                --connect-timeout 10 \
                --max-time 30 \
                --retry 0 \
                -d "$body" \
                -o "$tmpfile" 2>/dev/null) || true
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
                -H "Content-Type: application/json" \
                -H "User-Agent: CBUP-Agent/${AGENT_VERSION} (Linux)" \
                -H "X-Agent-Id: ${AGENT_ID}" \
                -H "X-Agent-Version: ${AGENT_VERSION}" \
                ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"} \
                --connect-timeout 10 \
                --max-time 30 \
                --retry 0 \
                -o "$tmpfile" 2>/dev/null) || true
        fi

        http_code=$(echo "$response" | tail -1)
        local body_content
        body_content=$(head -n -1 "$tmpfile" 2>/dev/null)
        rm -f "$tmpfile"

        if [[ "$http_code" =~ ^2 ]]; then
            log_debug "API ${method} ${endpoint} -> ${http_code} (attempt ${attempt})"
            # Return body content (echo for capture)
            echo "$body_content"
            return 0
        else
            if [[ $attempt -lt $MAX_RETRIES ]]; then
                local backoff=$((RETRY_DELAY * (2 ** (attempt - 1))))
                [[ $backoff -gt 60 ]] && backoff=60
                log_warn "API ${method} ${endpoint} failed (attempt ${attempt}/${MAX_RETRIES}): HTTP ${http_code}. Retrying in ${backoff}s..."
                sleep "$backoff"
            else
                log_error "API ${method} ${endpoint} failed after ${attempt} attempts: HTTP ${http_code}"
                return 1
            fi
        fi
    done

    return 1
}

# =============================================================================
# SYSTEM DISCOVERY
# =============================================================================

collect_system_discovery() {
    log_info "Collecting system discovery data..."

    local hostname domain os_name os_version kernel arch cpu_model cpu_cores
    local total_ram_mb serial_number manufacturer model bios_version
    local mac_addresses ip_addresses disks logged_users timezone

    # --- Hostname & Domain ---
    hostname=$(hostname -s 2>/dev/null || echo "unknown")
    domain=$(hostname -d 2>/dev/null || echo "")
    [[ -z "$domain" ]] && domain=$(cat /etc/resolv.conf 2>/dev/null | awk '/^search/ {print $2; exit}' || echo "")
    [[ -z "$domain" ]] && domain="WORKGROUP"

    # --- OS Information ---
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep "^PRETTY_NAME=" /etc/os-release 2>/dev/null | cut -d'"' -f2)
        os_version=$(grep "^VERSION_ID=" /etc/os-release 2>/dev/null | cut -d'"' -f2)
    else
        os_name=$(cat /etc/issue 2>/dev/null | head -1 | tr -d '\n' || echo "Unknown Linux")
        os_version="unknown"
    fi

    # --- Kernel ---
    kernel=$(uname -r 2>/dev/null || echo "unknown")

    # --- Architecture ---
    arch=$(uname -m 2>/dev/null || echo "unknown")

    # --- CPU ---
    cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "unknown")
    cpu_cores=$(nproc 2>/dev/null || echo "1")

    # --- RAM (in MB) ---
    local ram_kb
    ram_kb=$(grep "^MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [[ -n "$ram_kb" ]]; then
        total_ram_mb=$((ram_kb / 1024))
    else
        total_ram_mb=0
    fi

    # --- Serial Number & Manufacturer & Model & BIOS (via dmidecode) ---
    if command -v dmidecode &>/dev/null && [[ $EUID -eq 0 ]]; then
        serial_number=$(dmidecode -s system-serial-number 2>/dev/null | head -1 || echo "")
        manufacturer=$(dmidecode -s system-manufacturer 2>/dev/null | head -1 || echo "")
        model=$(dmidecode -s system-product-name 2>/dev/null | head -1 || echo "")
        bios_version=$(dmidecode -s bios-version 2>/dev/null | head -1 || echo "")
        [[ -n "$bios_version" ]] && bios_version="${bios_version} ($(dmidecode -s bios-release-date 2>/dev/null | head -1 || echo "unknown"))"
    else
        serial_number=""
        manufacturer=""
        model=""
        bios_version=""
    fi

    # --- MAC Addresses ---
    mac_addresses=$(ip -br link 2>/dev/null | grep -v "lo" | awk '{print $3}' | grep -v "^$" | tr '\n' ',' | sed 's/,$//' || echo "")
    [[ -z "$mac_addresses" ]] && mac_addresses=$(cat /sys/class/net/*/address 2>/dev/null | grep -v "00:00:00:00:00:00" | tr '\n' ',' | sed 's/,$//')

    # --- IP Addresses ---
    ip_addresses=$(ip -4 -o addr show 2>/dev/null | grep -v "lo" | awk '{print $4}' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//' || echo "")
    [[ -z "$ip_addresses" ]] && ip_addresses=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")

    # --- Disk Info (JSON array) ---
    disks=$(df -BM --output=source,target,size,avail,pcent -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | \
        awk -F' *' '{
            gsub(/M$/, "", $3); gsub(/M$/, "", $4); gsub(/%$/, "", $5);
            printf "{\"device\":\"%s\",\"mount\":\"%s\",\"totalMB\":%s,\"freeMB\":%s,\"usedPct\":%s},", $1, $2, $3, $4, $5
        }' | sed 's/,$//')
    disks="[$disks]"

    # --- Logged-in Users ---
    logged_users=$(who 2>/dev/null | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//' || echo "")

    # --- Timezone ---
    timezone=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "UTC")

    # --- Build JSON payload ---
    local discovery_json
    discovery_json=$(cat <<JSONEOF
{
    "agentId": "${AGENT_ID}",
    "hostname": "$(echo "$hostname" | sed 's/"/\\"/g')",
    "domain": "$(echo "$domain" | sed 's/"/\\"/g')",
    "osName": "$(echo "$os_name" | sed 's/"/\\"/g')",
    "osVersion": "$(echo "$os_version" | sed 's/"/\\"/g')",
    "osArch": "${arch}",
    "manufacturer": "$(echo "$manufacturer" | sed 's/"/\\"/g')",
    "model": "$(echo "$model" | sed 's/"/\\"/g')",
    "serialNumber": "$(echo "$serial_number" | sed 's/"/\\"/g')",
    "biosVersion": "$(echo "$bios_version" | sed 's/"/\\"/g')",
    "cpuModel": "$(echo "$cpu_model" | sed 's/"/\\"/g')",
    "cpuCores": ${cpu_cores},
    "totalRamMb": ${total_ram_mb},
    "macAddresses": "$(echo "$mac_addresses" | sed 's/"/\\"/g')",
    "ipAddresses": "$(echo "$ip_addresses" | sed 's/"/\\"/g')",
    "version": "${AGENT_VERSION}",
    "platform": "linux",
    "kernel": "${kernel}",
    "disks": ${disks},
    "loggedInUsers": "$(echo "$logged_users" | sed 's/"/\\"/g')",
    "timezone": "${timezone}"
}
JSONEOF
    )

    log_info "System discovery completed. Hostname=${hostname}, OS=${os_name}"
    echo "$discovery_json"
}

# =============================================================================
# TELEMETRY COLLECTION
# =============================================================================

get_cpu_usage() {
    # Parse /proc/stat: first line is aggregate, subsequent lines are per-core
    local cpu_total_percent=0
    local per_core_json="["

    local core_index=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^cpu[[:space:]] ]]; then
            # Aggregate CPU line
            local vals=($line)
            local idle=${vals[4]}
            local total=0
            for v in "${vals[@]:1}"; do
                total=$((total + v))
            done

            # Use global variables for delta calculation
            if [[ ${_PREV_CPU_TOTAL:-0} -gt 0 ]]; then
                local total_diff=$((total - _PREV_CPU_TOTAL))
                local idle_diff=$((idle - _PREV_CPU_IDLE))
                if [[ $total_diff -gt 0 ]]; then
                    cpu_total_percent=$(awk "BEGIN {printf \"%.1f\", (1 - ${idle_diff}/${total_diff}) * 100}")
                fi
            fi
            _PREV_CPU_TOTAL=$total
            _PREV_CPU_IDLE=$idle
        elif [[ "$line" =~ ^cpu[0-9]+ ]]; then
            # Per-core line
            local vals=($line)
            local core_name=${vals[0]}
            local idle=${vals[4]}
            local total=0
            for v in "${vals[@]:1}"; do
                total=$((total + v))
            done

            local key="_PREV_CPU_${core_index}_TOTAL"
            local idle_key="_PREV_CPU_${core_index}_IDLE"
            local prev_total=${!key:-0}
            local prev_idle=${!idle_key:-0}
            local core_percent=0

            if [[ $prev_total -gt 0 ]]; then
                local total_diff=$((total - prev_total))
                local idle_diff=$((idle - prev_idle))
                if [[ $total_diff -gt 0 ]]; then
                    core_percent=$(awk "BEGIN {printf \"%.1f\", (1 - ${idle_diff}/${total_diff}) * 100}")
                fi
            fi

            # Store for next iteration using eval
            eval "_PREV_CPU_${core_index}_TOTAL=$total"
            eval "_PREV_CPU_${core_index}_IDLE=$idle"

            [[ $core_index -gt 0 ]] && per_core_json+=","
            per_core_json+="{\"core\":\"${core_name}\",\"percent\":${core_percent}}"
            core_index=$((core_index + 1))
        fi
    done < /proc/stat

    per_core_json+="]"
    echo "{\"total\":${cpu_total_percent},\"perCore\":${per_core_json}}"
}

get_memory_usage() {
    local mem_total mem_free mem_available mem_buffers mem_cached mem_used mem_percent
    local mem_total_mb mem_used_mb mem_available_mb

    # Parse /proc/meminfo (values in kB)
    mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_free=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    mem_buffers=$(awk '/^Buffers:/ {print $2}' /proc/meminfo)
    mem_cached=$(awk '/^Cached:/ {print $2}' /proc/meminfo)

    # Calculate used = total - available (if available is reported), else total - free - buffers - cached
    if [[ -n "$mem_available" && "$mem_available" -gt 0 ]]; then
        mem_used=$((mem_total - mem_available))
    else
        mem_used=$((mem_total - mem_free - mem_buffers - mem_cached))
    fi

    mem_percent=$(awk "BEGIN {printf \"%.1f\", (${mem_used}/${mem_total}) * 100}")

    mem_total_mb=$((mem_total / 1024))
    mem_used_mb=$((mem_used / 1024))
    mem_available_mb=$((mem_total_mb - mem_used_mb))

    echo "{\"totalMB\":${mem_total_mb},\"usedMB\":${mem_used_mb},\"availableMB\":${mem_available_mb},\"usedPercent\":${mem_percent}}"
}

get_disk_io() {
    # Collect disk I/O stats from /proc/diskstats for major block devices
    local current_time
    current_time=$(date +%s%N)

    local disk_io_json="["
    local first=1

    while IFS= read -r line; do
        local cols=($line)
        local dev_name=${cols[2]}
        # Skip non-physical devices
        [[ "$dev_name" =~ ^(ram|loop|fd|zram|sr|md) ]] && continue
        # Skip partition entries (names with numbers at end for common disks)
        # We only want the base device

        local reads_completed=${cols[3]}
        local reads_merged=${cols[4]}
        local sectors_read=${cols[5]}
        local read_time_ms=${cols[6]}
        local writes_completed=${cols[7]}
        local writes_merged=${cols[8]}
        local sectors_written=${cols[9]}
        local write_time_ms=${cols[10]}

        # Sectors are 512 bytes each
        local bytes_read=$((sectors_read * 512))
        local bytes_written=$((sectors_written * 512))

        local key="PREV_DISK_${dev_name}"
        local prev_val="${PREV_DISK_STATS[$dev_name]:-}"
        local read_bps=0
        local write_bps=0

        if [[ -n "$prev_val" ]]; then
            local prev_bytes_read prev_bytes_written prev_time
            IFS='|' read -r prev_bytes_read prev_bytes_written prev_time <<< "$prev_val"

            local time_diff_ns=$((current_time - prev_time))
            if [[ $time_diff_ns -gt 0 ]]; then
                local time_diff_sec
                time_diff_sec=$(awk "BEGIN {printf \"%.2f\", ${time_diff_ns}/1000000000}")
                read_bps=$(awk "BEGIN {printf \"%.0f\", (${bytes_read} - ${prev_bytes_read})/${time_diff_sec}")
                write_bps=$(awk "BEGIN {printf \"%.0f\", (${bytes_written} - ${prev_bytes_written})/${time_diff_sec}")
            fi
        fi

        PREV_DISK_STATS["$dev_name"]="${bytes_read}|${bytes_written}|${current_time}"

        # Only include devices with I/O activity
        [[ $read_bps -eq 0 && $write_bps -eq 0 && -z "$prev_val" ]] && continue

        [[ $first -eq 0 ]] && disk_io_json+=","
        disk_io_json+="{\"device\":\"${dev_name}\",\"readBps\":${read_bps},\"writeBps\":${write_bps}}"
        first=0
    done < /proc/diskstats

    disk_io_json+="]"
    echo "$disk_io_json"
}

get_disk_space() {
    # Disk space for each mount point (returns JSON with free/total in GB)
    local disk_space_json="["
    local first=1

    while IFS= read -r line; do
        # Skip header and lines starting with special chars
        [[ -z "$line" || "$line" =~ ^(Filesystem|overlay|tmpfs|devtmpfs) ]] && continue

        local cols=($line)
        local device=${cols[0]}
        local total_kb=${cols[1]}
        local used_kb=${cols[2]}
        local avail_kb=${cols[3]}
        local pct=${cols[4]}
        local mount=${cols[5]}

        local total_gb used_gb free_gb
        total_gb=$(awk "BEGIN {printf \"%.2f\", ${total_kb}/1048576}")
        used_gb=$(awk "BEGIN {printf \"%.2f\", ${used_kb}/1048576}")
        free_gb=$(awk "BEGIN {printf \"%.2f\", ${avail_kb}/1048576}")
        pct=$(echo "$pct" | tr -d '%')

        [[ $first -eq 0 ]] && disk_space_json+=","
        disk_space_json+="{\"device\":\"${device}\",\"mount\":\"${mount}\",\"totalGB\":${total_gb},\"usedGB\":${used_gb},\"freeGB\":${free_gb},\"usedPct\":${pct}}"
        first=0
    done < <(df -B1K --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null)

    disk_space_json+="]"
    echo "$disk_space_json"
}

get_network_io() {
    # Collect network I/O from /proc/net/dev
    local current_time
    current_time=$(date +%s%N)

    local net_io_json="["
    local first=1

    while IFS= read -r line; do
        # Format: "  eth0: 1234 567 890 12 ... 3456 789 012 34 ..."
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ ! "$line" =~ : ]] && continue

        local iface
        iface=$(echo "$line" | awk -F':' '{print $1}' | xargs)
        [[ "$iface" == "lo" ]] && continue

        local data
        data=$(echo "$line" | awk -F':' '{print $2}')
        local cols=($data)

        local rx_bytes=${cols[0]}
        local tx_bytes=${cols[8]}

        local prev_val="${PREV_NET_STATS[$iface]:-}"
        local in_bps=0
        local out_bps=0

        if [[ -n "$prev_val" ]]; then
            local prev_rx prev_tx prev_time
            IFS='|' read -r prev_rx prev_tx prev_time <<< "$prev_val"

            local time_diff_ns=$((current_time - prev_time))
            if [[ $time_diff_ns -gt 0 ]]; then
                local time_diff_sec
                time_diff_sec=$(awk "BEGIN {printf \"%.2f\", ${time_diff_ns}/1000000000}")
                in_bps=$(awk "BEGIN {printf \"%.0f\", (${rx_bytes} - ${prev_rx})/${time_diff_sec}")
                out_bps=$(awk "BEGIN {printf \"%.0f\", (${tx_bytes} - ${prev_tx})/${time_diff_sec}")
            fi
        fi

        PREV_NET_STATS["$iface"]="${rx_bytes}|${tx_bytes}|${current_time}"

        [[ $first -eq 0 ]] && net_io_json+=","
        net_io_json+="{\"interface\":\"${iface}\",\"inBps\":${in_bps},\"outBps\":${out_bps}}"
        first=0
    done < /proc/net/dev

    net_io_json+="]"
    echo "$net_io_json"
}

get_top_cpu_processes() {
    # Top 5 CPU-consuming processes
    local procs_json="["
    local first=1

    ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | while IFS= read -r line; do
        local cols=($line)
        local user=${cols[0]}
        local pid=${cols[1]}
        local cpu=${cols[2]}
        local mem=${cols[3]}
        local comm=${cols[10]}

        [[ $first -eq 0 ]] && procs_json+=","
        procs_json+="{\"pid\":${pid},\"user\":\"${user}\",\"name\":\"${comm}\",\"cpuPct\":${cpu},\"memPct\":${mem}}"
        first=0
    done

    procs_json+="]"
    echo "$procs_json"
}

get_top_mem_processes() {
    # Top 5 memory-consuming processes
    local procs_json="["
    local first=1

    ps aux --sort=-%mem 2>/dev/null | head -6 | tail -5 | while IFS= read -r line; do
        local cols=($line)
        local user=${cols[0]}
        local pid=${cols[1]}
        local cpu=${cols[2]}
        local mem=${cols[3]}
        local comm=${cols[10]}

        [[ $first -eq 0 ]] && procs_json+=","
        procs_json+="{\"pid\":${pid},\"user\":\"${user}\",\"name\":\"${comm}\",\"cpuPct\":${cpu},\"memPct\":${mem}}"
        first=0
    done

    procs_json+="]"
    echo "$procs_json"
}

get_tcp_connections() {
    local count
    count=$(ss -t state established 2>/dev/null | wc -l)
    echo "$count"
}

get_uptime() {
    local uptime_sec
    uptime_sec=$(awk '{printf "%.0f", $1}' /proc/uptime 2>/dev/null || echo "0")
    echo "$uptime_sec"
}

get_process_count() {
    local count
    count=$(ps aux 2>/dev/null | wc -l)
    echo "$((count - 1))"  # Subtract header line
}

collect_telemetry() {
    log_debug "Collecting telemetry data..."

    local cpu_json mem_json disk_io_json disk_space_json net_io_json
    local top_cpu_json top_mem_json tcp_count uptime_sec proc_count
    local cpu_total cpu_total_float mem_total_mb mem_used_mb mem_percent
    local disk_read_bps=0 disk_write_bps=0 net_in_bps=0 net_out_bps=0
    local disk_free_gb=0 disk_total_gb=0

    # Collect all metrics
    cpu_json=$(get_cpu_usage)
    mem_json=$(get_memory_usage)
    disk_io_json=$(get_disk_io)
    disk_space_json=$(get_disk_space)
    net_io_json=$(get_network_io)
    top_cpu_json=$(get_top_cpu_processes)
    top_mem_json=$(get_top_mem_processes)
    tcp_count=$(get_tcp_connections)
    uptime_sec=$(get_uptime)
    proc_count=$(get_process_count)

    # Parse top-level values from JSON (using simple awk since we control the format)
    cpu_total_float=$(echo "$cpu_json" | awk -F'"total":' '{print $2}' | awk -F',' '{print $1}' | xargs)
    cpu_total=$(printf "%.1f" "$cpu_total_float")
    mem_total_mb=$(echo "$mem_json" | awk -F'"totalMB":' '{print $2}' | awk -F',' '{print $1}' | xargs)
    mem_used_mb=$(echo "$mem_json" | awk -F'"usedMB":' '{print $2}' | awk -F',' '{print $1}' | xargs)
    mem_percent=$(echo "$mem_json" | awk -F'"usedPercent":' '{print $2}' | awk -F',' '{print $1}' | xargs)

    # Sum disk I/O across all devices
    disk_read_bps=$(echo "$disk_io_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /readBps/) { split($i, a, ":"); sum_r += a[2]+0 }
            if ($i ~ /writeBps/) { split($i, a, ":"); sum_w += a[2]+0 }
        }
    } END { print sum_r+0 }')
    disk_write_bps=$(echo "$disk_io_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /writeBps/) { split($i, a, ":"); sum_w += a[2]+0 }
        }
    } END { print sum_w+0 }')

    # Sum network I/O across all interfaces
    net_in_bps=$(echo "$net_io_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /inBps/) { split($i, a, ":"); sum_in += a[2]+0 }
            if ($i ~ /outBps/) { split($i, a, ":"); sum_out += a[2]+0 }
        }
    } END { print sum_in+0 }')
    net_out_bps=$(echo "$net_io_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /outBps/) { split($i, a, ":"); sum_out += a[2]+0 }
        }
    } END { print sum_out+0 }')

    # First disk's free/total for backward compat
    disk_free_gb=$(echo "$disk_space_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /freeGB/) { split($i, a, ":"); print a[2]+0; exit }
        }
    }')
    disk_total_gb=$(echo "$disk_space_json" | awk '{
        gsub(/[{\"}]/, "")
        for(i=1;i<=NF;i++) {
            if ($i ~ /totalGB/) { split($i, a, ":"); print a[2]+0; exit }
        }
    }')

    local telemetry_json
    telemetry_json=$(cat <<JSONEOF
{
    "agentId": "${AGENT_ID}",
    "authToken": "${AUTH_TOKEN}",
    "telemetry": {
        "cpuPercent": ${cpu_total:-0},
        "memPercent": ${mem_percent:-0},
        "memUsedMb": ${mem_used_mb:-0},
        "memTotalMb": ${mem_total_mb:-0},
        "diskReadBps": ${disk_read_bps:-0},
        "diskWriteBps": ${disk_write_bps:-0},
        "netInBps": ${net_in_bps:-0},
        "netOutBps": ${net_out_bps:-0},
        "diskFreeGb": ${disk_free_gb:-0},
        "diskTotalGb": ${disk_total_gb:-0},
        "activeTcp": ${tcp_count:-0},
        "uptime": ${uptime_sec:-0},
        "topCpuProcs": ${top_cpu_json},
        "topMemProcs": ${top_mem_json}
    }
}
JSONEOF
    )

    echo "$telemetry_json"
}

send_heartbeat() {
    local telemetry_json
    telemetry_json=$(collect_telemetry)

    local response
    response=$(api_call "POST" "/api/agents/heartbeat" "$telemetry_json")

    if [[ $? -eq 0 ]]; then
        LAST_HEARTBEAT_SUCCESS=$(date +%s)
        log_debug "Heartbeat sent successfully."
    else
        log_warn "Heartbeat failed."
    fi
}

# =============================================================================
# EDR SCAN ENGINE
# =============================================================================

edr_process_scan() {
    log_info "Starting EDR process scan..."
    local findings_json="["
    local suspicious_count=0
    local first=1

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local cols=($line)
        local user=${cols[0]}
        local pid=${cols[1]}
        local cpu=${cols[2]}
        local mem=${cols[3]}
        local vsz=${cols[4]}
        local rss=${cols[5]}
        local tty=${cols[6]}
        local stat=${cols[7]}
        local start=${cols[8]}
        local comm=${cols[10]:-unknown}
        local cmd=$(echo "$line" | cut -c41-)

        # Get full executable path
        local exe_path=""
        if [[ -f "/proc/${pid}/exe" ]]; then
            exe_path=$(readlink -f "/proc/${pid}/exe" 2>/dev/null || echo "")
        fi

        local flags=""
        local severity="info"

        # Flag: Running from /tmp or /var/tmp
        if [[ "$exe_path" =~ ^/tmp/|^/var/tmp/ ]]; then
            flags="TEMP_DIR"
            severity="high"
        fi

        # Flag: Known suspicious names
        if echo "$comm $cmd" | grep -qiE "$SUSPICIOUS_PROC_PATTERNS"; then
            flags="${flags} SUSPICIOUS_NAME"
            severity="critical"
        fi

        # Flag: Executable path doesn't exist (deleted binary)
        if [[ -n "$exe_path" && ! -f "$exe_path" ]]; then
            flags="${flags} DELETED_BINARY"
            [[ "$severity" == "info" ]] && severity="medium"
        fi

        # Flag: Process with no path
        if [[ -z "$exe_path" ]]; then
            flags="${flags} NO_PATH"
        fi

        local is_suspicious="false"
        if [[ -n "$flags" ]]; then
            is_suspicious="true"
            suspicious_count=$((suspicious_count + 1))
        fi

        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+=$(cat <<FINDJSON
{"pid":${pid},"user":"${user}","name":"${comm}","path":"$(echo "$exe_path" | sed 's/"/\\"/g')","cmdline":"$(echo "$cmd" | head -c 256 | sed 's/"/\\"/g')","cpuPct":${cpu},"memPct":${mem},"flags":"${flags}","suspicious":${is_suspicious},"severity":"${severity}"}
FINDJSON
        )
        first=0
    done < <(ps aux --no-headers 2>/dev/null)

    findings_json+="]"
    log_info "Process scan complete. Total=$(ps aux --no-headers 2>/dev/null | wc -l), Suspicious=${suspicious_count}"

    echo "{\"findings\":${findings_json},\"suspiciousCount\":${suspicious_count}}"
}

edr_service_scan() {
    log_info "Starting EDR service scan..."
    local findings_json="["
    local suspicious_count=0
    local first=1

    while IFS= read -r svc; do
        local svc_name svc_load svc_active svc_sub svc_desc
        read -r svc_load svc_active svc_sub svc_desc <<< "$svc"
        svc_name=$(echo "$svc_desc" | head -1)

        local flags=""
        local severity="info"
        local exe_path=""
        local status=""

        # Get unit file path and status details
        if systemctl show "$svc_name" &>/dev/null; then
            local fragment_path
            fragment_path=$(systemctl show "$svc_name" -p FragmentPath --value 2>/dev/null || echo "")
            status=$(systemctl show "$svc_name" -p ActiveState --value 2>/dev/null || echo "unknown")
            exe_path=$(systemctl show "$svc_name" -p ExecStart --value 2>/dev/null | head -1 | awk '{print $1}' || echo "")

            # Flag: Service with unusual path
            if [[ -n "$exe_path" && "$exe_path" =~ ^/tmp/|^/var/tmp/|^/dev/shm/ ]]; then
                flags="UNUSUAL_PATH"
                severity="critical"
            fi

            # Flag: Script-based service binary
            if [[ -n "$exe_path" && "$exe_path" =~ \.(sh|py|pl|rb|js|vbs)$ ]]; then
                flags="${flags} SCRIPT_SERVICE"
                [[ "$severity" == "info" ]] && severity="medium"
            fi

            # Flag: Failed service
            if [[ "$status" == "failed" ]]; then
                flags="${flags} FAILED"
                [[ "$severity" == "info" ]] && severity="medium"
            fi

            # Flag: Auto-start but not running
            local unit_state
            unit_state=$(systemctl is-enabled "$svc_name" 2>/dev/null || echo "unknown")
            if [[ "$unit_state" == "enabled" && "$status" != "active" ]]; then
                flags="${flags} AUTO_START_STOPPED"
                [[ "$severity" == "info" ]] && severity="low"
            fi

            # Check if executable is unsigned (for non-system paths)
            if [[ -n "$exe_path" && -f "$exe_path" && ! "$exe_path" =~ ^/(usr|lib|bin|sbin)/ ]]; then
                if command -v dpkg &>/dev/null && ! dpkg -S "$exe_path" &>/dev/null; then
                    flags="${flags} UNSIGNED_NON_SYSTEM"
                    [[ "$severity" == "info" || "$severity" == "low" ]] && severity="medium"
                fi
            fi
        fi

        local is_suspicious="false"
        if [[ -n "$flags" ]]; then
            is_suspicious="true"
            suspicious_count=$((suspicious_count + 1))
        fi

        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+=$(cat <<SVCJSON
{"name":"$(echo "$svc_name" | sed 's/"/\\"/g')","status":"${status}","path":"$(echo "$exe_path" | sed 's/"/\\"/g')","flags":"${flags}","suspicious":${is_suspicious},"severity":"${severity}"}
SVCJSON
        )
        first=0
    done < <(systemctl list-units --type=service --all --no-legend 2>/dev/null)

    findings_json+="]"
    log_info "Service scan complete. Suspicious=${suspicious_count}"
    echo "{\"findings\":${findings_json},\"suspiciousCount\":${suspicious_count}}"
}

edr_port_scan() {
    log_info "Starting EDR port scan..."
    local findings_json="["
    local suspicious_count=0
    local first=1

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local cols=($line)
        # ss -tlnp output format: STATE  RECV-Q  SEND-Q  LOCAL  PORT  ADDRESS  REMOTE  PORT
        local state=${cols[0]}
        local local_addr=${cols[4]}
        local port="${local_addr##*:}"
        local process="${cols[6]:-}"

        local flags=""
        local severity="info"
        local pid="" proc_name=""

        # Extract PID and process name
        if [[ "$process" =~ users:\(\(\"([^\"]+)\"[^,]*,pid=([0-9]+) ]]; then
            proc_name="${BASH_REMATCH[1]}"
            pid="${BASH_REMATCH[2]}"
        elif [[ "$process" =~ pid=([0-9]+) ]]; then
            pid="${BASH_REMATCH[1]}"
            proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        fi

        # Flag suspicious ports
        for sp in $SUSPICIOUS_PORTS; do
            if [[ "$port" == "$sp" ]]; then
                flags="SUSPICIOUS_PORT"
                severity="high"
                break
            fi
        done

        # Flag uncommon privileged ports (< 1024)
        if [[ "$port" -lt 1024 ]] && [[ "$port" -ne 22 && "$port" -ne 80 && "$port" -ne 443 && "$port" -ne 53 && "$port" -ne 25 && "$port" -ne 110 && "$port" -ne 143 && "$port" -ne 993 && "$port" -ne 995 && "$port" -ne 587 && "$port" -ne 88 && "$port" -ne 389 && "$port" -ne 636 && "$port" -ne 111 ]]; then
            if [[ -z "$flags" ]]; then
                flags="UNCOMMON_PRIVILEGED_PORT"
                [[ "$severity" == "info" ]] && severity="low"
            fi
        fi

        local is_suspicious="false"
        if [[ -n "$flags" ]]; then
            is_suspicious="true"
            suspicious_count=$((suspicious_count + 1))
        fi

        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+=$(cat <<PORTJSON
{"port":${port},"protocol":"TCP","address":"${local_addr%:*}","pid":"${pid}","process":"${proc_name}","flags":"${flags}","suspicious":${is_suspicious},"severity":"${severity}"}
PORTJSON
        )
        first=0
    done < <(ss -tlnp 2>/dev/null)

    findings_json+="]"
    log_info "Port scan complete. Suspicious=${suspicious_count}"
    echo "{\"findings\":${findings_json},\"suspiciousCount\":${suspicious_count}}"
}

edr_autorun_scan() {
    log_info "Starting EDR autorun scan..."
    local findings_json="["
    local suspicious_count=0
    local first=1

    # --- 1. System-wide crontabs ---
    for crontab_file in /etc/crontab /etc/cron.d/*; do
        [[ ! -f "$crontab_file" ]] && continue
        while IFS= read -r cron_line; do
            [[ -z "$cron_line" || "$cron_line" =~ ^[[:space:]]*# ]] && continue
            local flags=""
            local severity="info"
            local cmd=$(echo "$cron_line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}' | xargs)

            # Check for commands not from safe prefixes
            if [[ -n "$cmd" && ! "$cmd" =~ $SAFE_AUTORUN_PREFIXES ]]; then
                flags="NON_STANDARD_PATH"
                severity="medium"
            fi

            # Check for network-related commands in cron
            if echo "$cmd" | grep -qiE "curl|wget|nc |ncat|python.*http|ruby.*http|perl.*http"; then
                flags="${flags} NETWORK_CMD"
                severity="high"
            fi

            if [[ -n "$flags" ]]; then
                suspicious_count=$((suspicious_count + 1))
                [[ $first -eq 0 ]] && findings_json+=","
                findings_json+=$(cat <<AUTJSON
{"location":"cron:${crontab_file}","name":"$(echo "$cron_line" | awk '{print $7}' | xargs)","value":"$(echo "$cmd" | sed 's/"/\\"/g')","flags":"${flags}","suspicious":true,"severity":"${severity}"}
AUTJSON
                )
                first=0
            fi
        done < "$crontab_file"
    done

    # --- 2. User crontabs ---
    while IFS= read -r user_cron; do
        [[ -z "$user_cron" ]] && continue
        local user_name=$(basename "$user_cron")
        while IFS= read -r cron_line; do
            [[ -z "$cron_line" || "$cron_line" =~ ^[[:space:]]*# ]] && continue
            local cmd=$(echo "$cron_line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}' | xargs)

            local flags=""
            local severity="info"

            if echo "$cmd" | grep -qiE "curl|wget|nc |ncat|python.*http|ruby.*http|perl.*http"; then
                flags="NETWORK_CMD"
                severity="high"
                suspicious_count=$((suspicious_count + 1))
                [[ $first -eq 0 ]] && findings_json+=","
                findings_json+=$(cat <<AUTJSON
{"location":"cron:user:${user_name}","name":"$(echo "$cron_line" | awk '{print $7}' | xargs)","value":"$(echo "$cmd" | sed 's/"/\\"/g')","flags":"${flags}","suspicious":true,"severity":"${severity}"}
AUTJSON
                )
                first=0
            fi
        done < "$user_cron" 2>/dev/null
    done < <(ls /var/spool/cron/crontabs/ 2>/dev/null)

    # --- 3. Systemd timers ---
    while IFS= read -r timer; do
        [[ -z "$timer" ]] && continue
        local timer_name timer_state timer_desc
        read -r timer_name timer_state timer_desc <<< "$timer"
        timer_name=$(echo "$timer_desc" | awk '{print $1}')

        local flags=""
        local severity="info"
        local unit=""

        unit=$(systemctl show "$timer_name" -p Unit --value 2>/dev/null || echo "")

        # Check if timer unit runs a script in non-standard location
        if [[ -n "$unit" ]] && systemctl cat "$unit" &>/dev/null; then
            local unit_exe
            unit_exe=$(systemctl cat "$unit" 2>/dev/null | grep "^ExecStart=" | head -1 | awk -F= '{print $2}' | awk '{print $1}')
            if [[ -n "$unit_exe" && ! "$unit_exe" =~ $SAFE_AUTORUN_PREFIXES ]]; then
                flags="NON_STANDARD_TIMER_PATH"
                severity="medium"
                suspicious_count=$((suspicious_count + 1))
            fi
        fi

        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+=$(cat <<AUTJSON
{"location":"systemd-timer","name":"${timer_name}","value":"${unit}","flags":"${flags}","suspicious":$( [[ -n "$flags" ]] && echo "true" || echo "false" ),"severity":"${severity}"}
AUTJSON
        )
        first=0
    done < <(systemctl list-timers --all --no-legend 2>/dev/null)

    # --- 4. /etc/init.d scripts ---
    if [[ -d /etc/init.d ]]; then
        while IFS= read -r init_script; do
            [[ -z "$init_script" ]] && continue
            local script_name=$(basename "$init_script")
            local flags=""
            local severity="info"

            # Check if it's not managed by update-rc.d or systemd
            if ! update-rc.d "$script_name" status 2>/dev/null && ! systemctl list-unit-files "${script_name}.service" 2>/dev/null | grep -q enabled; then
                flags="ORPHAN_INIT_SCRIPT"
                severity="low"
                suspicious_count=$((suspicious_count + 1))
            fi

            if [[ -n "$flags" ]]; then
                [[ $first -eq 0 ]] && findings_json+=","
                findings_json+=$(cat <<AUTJSON
{"location":"init.d","name":"${script_name}","value":"${init_script}","flags":"${flags}","suspicious":true,"severity":"${severity}"}
AUTJSON
                )
                first=0
            fi
        done < <(ls /etc/init.d/ 2>/dev/null)
    fi

    # --- 5. ~/.config/autostart (for all users with home dirs) ---
    while IFS= read -r autostart_dir; do
        [[ ! -d "$autostart_dir" ]] && continue
        while IFS= read -r desktop_file; do
            [[ ! -f "$desktop_file" ]] && continue
            local flags=""
            local severity="info"
            local desktop_name=$(basename "$desktop_file")
            local desktop_exec=$(grep "^Exec=" "$desktop_file" 2>/dev/null | head -1 | cut -d'=' -f2)

            if [[ -n "$desktop_exec" ]]; then
                local exe_path
                exe_path=$(echo "$desktop_exec" | awk '{print $1}')

                # Check if the executable exists
                if [[ ! -f "$exe_path" ]]; then
                    flags="TARGET_MISSING"
                    severity="medium"
                    suspicious_count=$((suspicious_count + 1))
                fi

                # Check for suspicious commands
                if echo "$desktop_exec" | grep -qiE "curl|wget|nc |ncat|python.*http|ruby.*http|perl.*http"; then
                    flags="${flags} NETWORK_CMD"
                    severity="high"
                    [[ "$suspicious_count" -eq 0 ]] && suspicious_count=$((suspicious_count + 1))
                fi
            fi

            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+=$(cat <<AUTJSON
{"location":"autostart","name":"${desktop_name}","value":"$(echo "$desktop_exec" | sed 's/"/\\"/g')","flags":"${flags}","suspicious":$( [[ -n "$flags" ]] && echo "true" || echo "false" ),"severity":"${severity}"}
AUTJSON
            )
            first=0
        done < <(ls "$autostart_dir"/*.desktop 2>/dev/null)
    done < <(find /home -maxdepth 3 -name "autostart" -type d 2>/dev/null)

    # Also check root's autostart
    if [[ -d /root/.config/autostart ]]; then
        while IFS= read -r desktop_file; do
            [[ ! -f "$desktop_file" ]] && continue
            local flags=""
            local severity="info"
            local desktop_name=$(basename "$desktop_file")
            local desktop_exec=$(grep "^Exec=" "$desktop_file" 2>/dev/null | head -1 | cut -d'=' -f2)
            if [[ -n "$desktop_exec" ]]; then
                local exe_path=$(echo "$desktop_exec" | awk '{print $1}')
                [[ ! -f "$exe_path" ]] && { flags="TARGET_MISSING"; severity="medium"; suspicious_count=$((suspicious_count + 1)); }
                if echo "$desktop_exec" | grep -qiE "curl|wget|nc |ncat"; then
                    flags="${flags} NETWORK_CMD"; severity="high"
                fi
            fi
            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+=$(cat <<AUTJSON
{"location":"autostart:root","name":"${desktop_name}","value":"$(echo "$desktop_exec" | sed 's/"/\\"/g')","flags":"${flags}","suspicious":$( [[ -n "$flags" ]] && echo "true" || echo "false" ),"severity":"${severity}"}
AUTJSON
            )
            first=0
        done < <(ls /root/.config/autostart/*.desktop 2>/dev/null)
    fi

    findings_json+="]"
    log_info "Autorun scan complete. Suspicious=${suspicious_count}"
    echo "{\"findings\":${findings_json},\"suspiciousCount\":${suspicious_count}}"
}

edr_vulnerability_scan() {
    log_info "Starting EDR vulnerability scan..."
    local findings_json="["
    local suspicious_count=0
    local first=1

    # --- 1. OS Updates ---
    local update_count=0
    if command -v apt-get &>/dev/null; then
        update_count=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    fi

    local update_status="PASS"
    local update_severity="info"
    if [[ "$update_count" -gt 0 ]]; then
        update_status="WARN"
        update_severity="low"
        suspicious_count=$((suspicious_count + 1))
    fi

    [[ $first -eq 0 ]] && findings_json+=","
    findings_json+="{\"check\":\"OS_Updates\",\"value\":\"${update_count} pending updates\",\"status\":\"${update_status}\",\"severity\":\"${update_severity}\"}"
    first=0

    # --- 2. SSH Configuration ---
    if [[ -f /etc/ssh/sshd_config ]]; then
        # Check root login
        local root_login
        root_login=$(grep -i "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        if [[ "$root_login" == "yes" ]]; then
            suspicious_count=$((suspicious_count + 1))
            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+="{\"check\":\"SSH_RootLogin\",\"value\":\"Root login is permitted\",\"status\":\"WARN\",\"severity\":\"high\"}"
            first=0
        else
            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+="{\"check\":\"SSH_RootLogin\",\"value\":\"Root login is ${root_login:-not explicitly set (default: prohibit-password)}\",\"status\":\"PASS\",\"severity\":\"info\"}"
            first=0
        fi

        # Check password authentication
        local password_auth
        password_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        if [[ "$password_auth" == "yes" ]]; then
            suspicious_count=$((suspicious_count + 1))
            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+="{\"check\":\"SSH_PasswordAuth\",\"value\":\"Password authentication is enabled\",\"status\":\"WARN\",\"severity\":\"medium\"}"
            first=0
        else
            [[ $first -eq 0 ]] && findings_json+=","
            findings_json+="{\"check\":\"SSH_PasswordAuth\",\"value\":\"Password auth is ${password_auth:-not explicitly set (default: yes)}\",\"status\":\"$( [[ "$password_auth" == "no" ]] && echo "PASS" || echo "WARN" )\",\"severity\":\"info\"}"
            first=0
        fi

        # Check for non-standard SSH port
        local ssh_port
        ssh_port=$(grep -i "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        ssh_port="${ssh_port:-22}"
        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+="{\"check\":\"SSH_Port\",\"value\":\"SSH listening on port ${ssh_port}\",\"status\":\"$( [[ "$ssh_port" -ne 22 ]] && echo "INFO" || echo "PASS" )\",\"severity\":\"info\"}"
        first=0
    fi

    # --- 3. Firewall Status ---
    local fw_status="DISABLED"
    local fw_active=0
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            fw_status="UFW_ACTIVE"
            fw_active=1
        fi
    fi

    if [[ $fw_active -eq 0 ]] && command -v iptables &>/dev/null; then
        local ipt_count
        ipt_count=$(iptables -L -n 2>/dev/null | grep -c "^Chain" || echo "0")
        if [[ "$ipt_count" -gt 3 ]]; then
            fw_status="IPTABLES_RULES"
            fw_active=1
        fi
    fi

    if [[ $fw_active -eq 0 ]]; then
        suspicious_count=$((suspicious_count + 1))
        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+="{\"check\":\"Firewall\",\"value\":\"No active firewall detected\",\"status\":\"WARN\",\"severity\":\"high\"}"
        first=0
    else
        [[ $first -eq 0 ]] && findings_json+=","
        findings_json+="{\"check\":\"Firewall\",\"value\":\"Firewall active (${fw_status})\",\"status\":\"PASS\",\"severity\":\"info\"}"
        first=0
    fi

    # --- 4. SUID/SGID binaries check (high-risk) ---
    local suid_count
    suid_count=$(find /usr -perm -4000 -type f 2>/dev/null | wc -l)
    [[ $first -eq 0 ]] && findings_json+=","
    findings_json+="{\"check\":\"SUID_Binaries\",\"value\":\"${suid_count} SUID binaries found in /usr\",\"status\":\"INFO\",\"severity\":\"info\"}"
    first=0

    # --- 5. Open ports summary ---
    local open_port_count
    open_port_count=$(ss -tlnp 2>/dev/null | tail -n +2 | wc -l)
    [[ $first -eq 0 ]] && findings_json+=","
    findings_json+="{\"check\":\"OpenPorts\",\"value\":\"${open_port_count} TCP ports listening\",\"status\":\"INFO\",\"severity\":\"info\"}"
    first=0

    findings_json+="]"
    log_info "Vulnerability scan complete. Issues found=${suspicious_count}"
    echo "{\"findings\":${findings_json},\"suspiciousCount\":${suspicious_count}}"
}

run_edr_scan() {
    local scan_type="$1"
    local scan_start
    scan_start=$(date +%s%N)

    local scan_result=""

    case "$scan_type" in
        process)
            scan_result=$(edr_process_scan)
            ;;
        service)
            scan_result=$(edr_service_scan)
            ;;
        port)
            scan_result=$(edr_port_scan)
            ;;
        autorun)
            scan_result=$(edr_autorun_scan)
            ;;
        vulnerability)
            scan_result=$(edr_vulnerability_scan)
            ;;
        *)
            log_error "Unknown scan type: ${scan_type}"
            return 1
            ;;
    esac

    local scan_end
    scan_end=$(date +%s%N)
    local duration_ms
    duration_ms=$(awk "BEGIN {printf \"%.0f\", (${scan_end} - ${scan_start})/1000000}")

    # Submit scan results to server
    local suspicious_count
    suspicious_count=$(echo "$scan_result" | awk -F'"suspiciousCount":' '{print $2}' | awk -F'}' '{print $1}' | xargs)
    local findings
    findings=$(echo "$scan_result" | awk -F'"findings":' '{print $2}' | sed 's/}}$//')

    local edr_json
    edr_json=$(cat <<JSONEOF
{
    "agentId": "${AGENT_ID}",
    "authToken": "${AUTH_TOKEN}",
    "scanType": "${scan_type}",
    "findings": ${findings},
    "summary": {"suspiciousCount": ${suspicious_count:-0}, "scanType": "${scan_type}"},
    "durationMs": ${duration_ms}
}
JSONEOF
    )

    local response
    response=$(api_call "POST" "/api/agents/edr-scan" "$edr_json")

    if [[ $? -eq 0 ]]; then
        log_info "EDR ${scan_type} scan results submitted. Suspicious=${suspicious_count:-0}, Duration=${duration_ms}ms"
    else
        log_warn "Failed to submit EDR ${scan_type} scan results."
    fi
}

run_all_edr_scans() {
    log_info "Running full EDR scan suite..."
    run_edr_scan "process"
    run_edr_scan "service"
    run_edr_scan "port"
    run_edr_scan "autorun"
    run_edr_scan "vulnerability"
    log_info "Full EDR scan suite completed."
}

# =============================================================================
# COMMAND & CONTROL
# =============================================================================

poll_and_execute_commands() {
    local response
    response=$(api_call "GET" "/api/agents/commands?agentId=${AGENT_ID}&authToken=${AUTH_TOKEN}" "")

    if [[ $? -ne 0 || -z "$response" ]]; then
        return
    fi

    # Parse commands (simple parsing - expect JSON array)
    local command_ids
    command_ids=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for cmd in data.get('commands', []):
        print(json.dumps(cmd))
except:
    pass
" 2>/dev/null)

    if [[ -z "$command_ids" ]]; then
        return
    fi

    while IFS= read -r cmd_json; do
        [[ -z "$cmd_json" ]] && continue

        local cmd_id cmd_type cmd_payload
        cmd_id=$(echo "$cmd_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
        cmd_type=$(echo "$cmd_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('type',''))" 2>/dev/null)
        cmd_payload=$(echo "$cmd_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get('payload','')) if d.get('payload') else '')" 2>/dev/null)

        log_info "Received command: id=${cmd_id}, type=${cmd_type}"

        local cmd_status="completed"
        local cmd_result=""
        local cmd_error=""

        case "$cmd_type" in
            edr_scan)
                local scan_type="process"
                if [[ -n "$cmd_payload" ]]; then
                    scan_type=$(echo "$cmd_payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('scanType','process'))" 2>/dev/null)
                fi
                run_edr_scan "$scan_type"
                cmd_result="{\"message\": \"EDR ${scan_type} scan executed\"}"
                ;;
            shell)
                local shell_cmd=""
                if [[ -n "$cmd_payload" ]]; then
                    shell_cmd=$(echo "$cmd_payload" | python3 -c "import json,sys; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)
                fi
                if [[ -n "$shell_cmd" ]]; then
                    log_warn "Executing shell command: ${shell_cmd}"
                    local cmd_output
                    cmd_output=$(eval "$shell_cmd" 2>&1)
                    local exit_code=$?
                    if [[ $exit_code -ne 0 ]]; then
                        cmd_status="failed"
                        cmd_error="Exit code: ${exit_code}"
                    fi
                    cmd_result="{\"output\": $(echo "$cmd_output" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()[:2000]))' 2>/dev/null)}"
                else
                    cmd_status="failed"
                    cmd_error="No command provided in payload"
                fi
                ;;
            system_info)
                local discovery
                discovery=$(collect_system_discovery)
                cmd_result="{\"discovery\": ${discovery}}"
                ;;
            ping)
                cmd_result="{\"message\": \"pong\", \"agentId\": \"${AGENT_ID}\", \"version\": \"${AGENT_VERSION}\"}"
                ;;
            restart)
                cmd_result="{\"message\": \"Restart requested. Service manager will handle restart.\"}"
                systemctl restart "${SERVICE_NAME}" 2>/dev/null || true
                ;;
            *)
                cmd_status="failed"
                cmd_error="Unknown command type: ${cmd_type}"
                ;;
        esac

        # Report result
        local result_json
        result_json=$(cat <<JSONEOF
{
    "agentId": "${AGENT_ID}",
    "authToken": "${AUTH_TOKEN}",
    "commandId": "${cmd_id}",
    "status": "${cmd_status}",
    "result": ${cmd_result},
    "error": "${cmd_error}"
}
JSONEOF
        )

        api_call "POST" "/api/agents/command-result" "$result_json" >/dev/null 2>&1
        log_info "Command ${cmd_id} result reported: ${cmd_status}"
    done <<< "$command_ids"
}

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

shutdown_handler() {
    log_info "Shutdown signal received. Cleaning up..."
    SHUTDOWN_REQUESTED=1
}

trap shutdown_handler SIGTERM SIGINT

# =============================================================================
# REGISTRATION
# =============================================================================

register_agent() {
    if [[ -z "$SERVER_URL" ]]; then
        log_error "Server URL not configured. Cannot register."
        return 1
    fi

    if [[ -z "$AGENT_ID" ]]; then
        AGENT_ID=$(generate_agent_id)
    fi

    log_info "Registering agent with server..."
    local discovery_json
    discovery_json=$(collect_system_discovery)

    local response
    response=$(api_call "POST" "/api/agents/register" "$discovery_json")

    if [[ $? -eq 0 && -n "$response" ]]; then
        # Extract auth token from response
        local token
        token=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('authToken', ''))
except:
    pass
" 2>/dev/null)

        if [[ -n "$token" ]]; then
            AUTH_TOKEN="$token"
            save_config
            log_info "Agent registered successfully. AgentId=${AGENT_ID}"
            return 0
        else
            log_error "Registration succeeded but no auth token received."
            return 1
        fi
    else
        log_error "Agent registration failed."
        return 1
    fi
}

# =============================================================================
# MAIN LOOP
# =============================================================================

main_loop() {
    log_info "CBUP Agent v${AGENT_VERSION} starting..."
    log_info "  Server URL:    ${SERVER_URL}"
    log_info "  Agent ID:      ${AGENT_ID}"
    log_info "  Interval:      ${TELEMETRY_INTERVAL}s"
    log_info "  Scan Interval: ${SCAN_INTERVAL}m"
    log_info "  Dev Mode:      ${DEV_MODE}"

    # Ensure config is saved
    save_config

    # Initialize CPU stats (need two readings for delta)
    get_cpu_usage >/dev/null
    sleep 1
    get_cpu_usage >/dev/null
    sleep 1

    local last_heartbeat=0
    local last_scan=0
    local last_command_poll=0
    local iteration=0

    while [[ $SHUTDOWN_REQUESTED -eq 0 ]]; do
        local current_time
        current_time=$(date +%s)
        iteration=$((iteration + 1))

        # Rotate logs periodically
        if [[ $((iteration % 60)) -eq 0 ]]; then
            rotate_logs
        fi

        # Heartbeat / Telemetry
        if [[ $((current_time - last_heartbeat)) -ge $TELEMETRY_INTERVAL ]]; then
            send_heartbeat
            last_heartbeat=$current_time
        fi

        # EDR Scan
        if [[ $SCAN_INTERVAL -gt 0 ]] && [[ $((current_time - last_scan)) -ge $((SCAN_INTERVAL * 60)) ]]; then
            run_all_edr_scans
            last_scan=$current_time
        fi

        # Command Polling
        if [[ $((current_time - last_command_poll)) -ge $COMMAND_POLL_INTERVAL ]]; then
            poll_and_execute_commands
            last_command_poll=$current_time
        fi

        # Sleep with responsive shutdown
        for _ in $(seq 1 5); do
            [[ $SHUTDOWN_REQUESTED -eq 1 ]] && break
            sleep 1
        done
    done

    log_info "CBUP Agent shut down gracefully."
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --server-url)
            SERVER_URL="$2"
            shift 2
            ;;
        --install)
            # Load existing config if present, then install
            load_config 2>/dev/null || true
            do_install
            exit $?
            ;;
        --uninstall)
            do_uninstall
            exit $?
            ;;
        --interval)
            TELEMETRY_INTERVAL="$2"
            shift 2
            ;;
        --scan-interval)
            SCAN_INTERVAL="$2"
            shift 2
            ;;
        --token)
            AUTH_TOKEN="$2"
            shift 2
            ;;
        --dev-mode)
            DEV_MODE=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate intervals
[[ $TELEMETRY_INTERVAL -lt 5 ]] && TELEMETRY_INTERVAL=5
[[ $TELEMETRY_INTERVAL -gt 300 ]] && TELEMETRY_INTERVAL=300

# Initialize
ensure_config_dir
load_config

# Check if running as service (no args after install)
if [[ $EUID -eq 0 && -z "$DEV_MODE" && ! "$*" =~ --dev-mode ]] && [[ -f "$CONFIG_FILE" && -n "$AGENT_ID" ]]; then
    DEV_MODE=0
fi

# Register if no auth token yet
if [[ -n "$SERVER_URL" && -z "$AUTH_TOKEN" ]]; then
    register_agent
fi

# Start main loop
main_loop
