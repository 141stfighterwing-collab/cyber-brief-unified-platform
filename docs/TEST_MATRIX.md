# Test Matrix — OS Compatibility

## Supported Platforms

Cyber Brief Unified Platform has been validated against the following operating systems. The `install.sh` script includes built-in detection and graceful fallbacks for each platform's quirks.

## Compatibility Matrix

| Feature | Ubuntu 20.04 | Ubuntu 22.04 | Ubuntu 24.04 | Linux Mint 21.x | Linux Mint 22.x | WSL2 (Ubuntu) | WSL2 (Debian) |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **OS Detection** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Package Manager** | ✅ apt-get | ✅ apt-get | ✅ apt-get | ✅ apt-get | ✅ apt-get | ✅ apt-get | ✅ apt-get |
| **Bun Installation** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Docker Install** | ✅ | ✅ | ✅ | ✅ (maps→ubuntu) | ✅ (maps→ubuntu) | ✅ | ✅ |
| **systemd Service** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ optional | ⚠️ optional |
| **Firewall (ufw)** | ✅ | ✅ | ✅ | ✅ | ✅ | ⏭️ N/A (Windows) | ⏭️ N/A (Windows) |
| **cbup CLI** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **cbup doctor** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (WSL-aware) | ✅ (WSL-aware) |
| **Dev Mode (--dev)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Port Detection** | ✅ ss | ✅ ss | ✅ ss | ✅ ss | ✅ ss | ✅ ss | ✅ ss |
| **Backup/Restore** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Uninstall** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Legend: ✅ Full support | ⚠️ Conditional (see notes) | ⏭️ Skipped (not applicable)

## Windows Agent Compatibility

| Feature | Windows 10 | Windows 11 | Windows Server 2016 | Windows Server 2019 | Windows Server 2022 |
|---------|:---:|:---:|:---:|:---:|:---:|
| **OS Detection** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **PowerShell Version** | ✅ 5.1 | ✅ 5.1+ | ✅ 5.1 | ✅ 5.1 | ✅ 5.1 |
| **Service Installation** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **System Discovery** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Telemetry Collection** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EDR Process Scan** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EDR Service Scan** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EDR Port Scan** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EDR Autorun Scan** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **EDR Vulnerability Scan** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **C2 Command Protocol** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **System Tray App** | ✅ | ✅ | N/A | N/A | N/A |
| **EXE Build (ps2exe)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Registry Persistence** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Event Log Integration** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Gzip Compression** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **TLS Validation** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Modular Architecture (15 modules)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Company Signature Verification** | ✅ | ✅ | ✅ | ✅ | ✅ |

Legend: ✅ Full support | ⚠️ Conditional (see notes) | N/A Not applicable

## Windows Native & Git for Windows Testing

| Test Case | Windows 10 (Native) | Windows 11 (Native) | Git for Windows (MinGW) | Windows PowerShell ISE |
|---------|:---:|:---:|:---:|:---:|
| **PowerShell 5.1 Execution** | ✅ | ✅ | ✅ (bundled) | ✅ |
| **PowerShell 7+ (pwsh) Execution** | ✅ | ✅ | ⚠️ optional | ⏭️ N/A |
| **Module Dot-Sourcing** | ✅ | ✅ | ✅ | ✅ |
| **Registry Access (HKLM)** | ✅ | ✅ | ⚠️ limited | ✅ |
| **WMI/CIM Queries** | ✅ | ✅ | ⚠️ partial | ✅ |
| **Service Management** | ✅ | ✅ | ⏭️ N/A | ✅ |
| **TCP Port Scanning** | ✅ | ✅ | ✅ | ✅ |
| **Signature Registry Writes** | ✅ | ✅ | ⚠️ limited | ✅ |
| **EXE Build via ps2exe** | ✅ | ✅ | ⚠️ .NET required | ✅ |
| **Gzip Compression** | ✅ | ✅ | ✅ | ✅ |
| **TLS 1.2+ Connections** | ✅ | ✅ | ✅ | ✅ |

Legend: ✅ Full support | ⚠️ Partial/conditional | ⏭️ Skipped (not applicable)

## Docker Agent Compatibility

| Feature | Docker CE 20+ | Docker CE 24+ | Docker Desktop (Win) | Docker Desktop (Mac) |
|---------|:---:|:---:|:---:|:---:|
| **Linux Agent Container** | ✅ | ✅ | ✅ (WSL2) | ✅ |
| **Server URL Config** | ✅ | ✅ | ✅ | ✅ |
| **Telemetry Reporting** | ✅ | ✅ | ✅ | ✅ |
| **EDR Scanning** | ✅ | ✅ | ✅ | ✅ |
| **Auto-Restart Policy** | ✅ | ✅ | ✅ | ✅ |
| **Health Checks** | ✅ | ✅ | ✅ | ✅ |
| **Log Rotation** | ✅ | ✅ | ✅ | ✅ |
| **Modular Agent (v2.1.0)** | ✅ | ✅ | ✅ | ✅ |

## Signature Verification Tests

| Test Case | Windows 10 | Windows 11 | Windows Server 2019 | Windows Server 2022 |
|---------|:---:|:---:|:---:|:---:|
| **Signature Generation (build-exe.ps1)** | ✅ | ✅ | ✅ | ✅ |
| **SHA256 Fingerprint Creation** | ✅ | ✅ | ✅ | ✅ |
| **Registry Write (HKLM:\\SOFTWARE\\CBUP)** | ✅ | ✅ | ✅ | ✅ |
| **Registry Read Verification** | ✅ | ✅ | ✅ | ✅ |
| **EXE Metadata Embedding** | ✅ | ✅ | ✅ | ✅ |
| **Startup Signature Validation** | ✅ | ✅ | ✅ | ✅ |
| **Tamper Detection (modified EXE)** | ✅ | ✅ | ✅ | ✅ |
| **Tamper Detection (modified registry)** | ✅ | ✅ | ✅ | ✅ |
| **Signature Rotation** | ✅ | ✅ | ✅ | ✅ |
| **Multi-Tenant Signature Isolation** | ✅ | ✅ | ✅ | ✅ |

Legend: ✅ Pass | ❌ Fail | ⚠️ Partial

## Platform-Specific Notes

### Ubuntu 20.04 LTS (Focal Fossa)
- Fully supported. Oldest officially tested version.
- Uses `apt-get` for package management.
- systemd is available and used for service management.
- Docker installs from `download.docker.com/linux/ubuntu focal`.
- Note: Some very old 20.04 installations may have outdated CA certificates — the installer installs `ca-certificates` explicitly.

### Ubuntu 22.04 LTS (Jammy Jellyfish)
- Fully supported. Recommended minimum version for production.
- All features work out of the box.
- Docker installs from `download.docker.com/linux/ubuntu jammy`.

### Ubuntu 24.04 LTS (Noble Numbat)
- Fully supported. Latest LTS with best hardware compatibility.
- Docker installs from `download.docker.com/linux/ubuntu noble`.
- Uses `ss` for port checking (netstat deprecated).

### Linux Mint 21.x (Vanessa/Victoria/Virginia)
- Based on Ubuntu 22.04 (Jammy).
- **Key fix**: The installer maps `ID=linuxmint` → `DOCKER_REPO_ID=ubuntu` because Docker doesn't publish a `linuxmint` repo.
- **Key fix**: Uses `UBUNTU_CODENAME=jammy` from `/etc/os-release` to resolve the correct Docker repository codename.
- All other features use `apt-get` identically to Ubuntu.
- Tested on Linux Mint 21.1, 21.2, 21.3.

### Linux Mint 22.x (Wilma)
- Based on Ubuntu 24.04 (Noble).
- Same Docker repo mapping as Mint 21.x (`linuxmint` → `ubuntu`).
- Uses `UBUNTU_CODENAME=noble` for Docker repo.
- Tested on Linux Mint 22.

### Windows WSL2 (Ubuntu-based)
- **systemd**: Not available by default. The installer detects this and falls back to manual process management.
- **No firewall**: Windows manages the host firewall. The installer skips `ufw`/`firewalld` configuration and notifies the user.
- **PATH resolution**: Bun installer may not update PATH correctly in WSL. The installer adds `/etc/profile.d/cbup.sh` as a fallback.
- **Port access**: WSL2 shares network with Windows. `localhost:3000` is accessible from Windows browsers.
- **Docker**: Docker Desktop for Windows works, or Docker Engine can be installed inside WSL2.
- **Memory/proc**: WSL may not have `procps` pre-installed. The installer adds it for `free`/`uptime` commands.
- **Enabling systemd** (recommended for full functionality):
  ```ini
  # /etc/wsl.conf
  [boot]
  systemd=true
  ```
  Then run `wsl --shutdown` from PowerShell and reopen WSL.

### Windows WSL2 (Debian-based)
- Same WSL2 considerations as above.
- Uses `apt-get` for package management.
- `unzip` may not be pre-installed — the installer handles this.

## Install Modes

### Bare Metal (default)
```bash
sudo ./install.sh
```
- Full installation with systemd service, firewall config, dedicated user
- Works on: Ubuntu, Linux Mint (with native systemd)
- Falls back to manual process on WSL (no systemd)

### Docker
```bash
sudo ./install.sh --docker
```
- Containerized installation
- Works on: All platforms
- Handles Docker Engine installation automatically

### Development
```bash
./install.sh --dev    # No sudo needed
```
- Lightweight install without systemd, firewall, or dedicated user
- Uses local database (`db/custom.db`)
- Skips production build
- Works on: All platforms including WSL without systemd

## Built-In Test Suite

Run the validation test suite before installing:

```bash
./install.sh --test
```

This runs 23+ automated checks:
- OS detection and version
- Package manager resolution
- Docker repo ID mapping
- Prerequisite tools (curl, git, unzip, gcc)
- Bun runtime detection
- systemd availability
- Port checking tools (ss, netstat, /proc/net/tcp)
- Port availability
- Filesystem permissions
- Docker availability and daemon status
- WSL-specific checks

## Manual Validation

To manually validate the installation on any supported platform:

```bash
# 1. Run pre-install tests
./install.sh --test

# 2. Install (choose your mode)
sudo ./install.sh --yes

# 3. Run diagnostics
cbup doctor

# 4. Check HTTP response
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
# Expected: 200

# 5. Test CLI commands
cbup status
cbup logs 10
cbup backup

# 6. Test uninstall (clean slate)
cbup uninstall
```

## Known Issues and Resolutions

### Issue: "systemctl not found" on WSL
**Resolution**: Enable systemd in WSL by adding `[boot]\nsystemd=true` to `/etc/wsl.conf`, then restart WSL with `wsl --shutdown`.

### Issue: "Port 3000 already in use"
**Resolution**: Use a different port: `sudo ./install.sh --port 8080`

### Issue: "Bun installed but not in PATH" on WSL
**Resolution**: Log out and back in, or run: `export PATH=$PATH:/usr/local/bin`

### Issue: Docker install fails on Linux Mint
**Resolution**: The installer now maps Linux Mint to Ubuntu's Docker repo. If it still fails, install Docker manually and re-run with `--docker`.

### Issue: "Cannot connect to Docker daemon" on WSL
**Resolution**: Start Docker manually: `sudo service docker start` or ensure Docker Desktop for Windows is running with WSL integration enabled.

### Issue: "Permission denied" writing to /opt/cbup
**Resolution**: Always run the bare-metal installer with `sudo`. For dev mode (no root), use `--dev`.
