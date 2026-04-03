# Patch Notes & Upgrade Guide

This document provides per-version patch notes, security fix descriptions, breaking change notices, and upgrade instructions for the Cyber Brief Unified Platform (CBUP).

---

## v2.1.0 — 2026-04-03

### Summary

v2.1.0 is a feature and bug-fix release focused on the Windows PowerShell agent. It introduces a modular architecture (15 modules replacing the 2,296-line monolith), a company-specific code signing system for EXE downloads, and 7 bug fixes across EDR scanning, telemetry collection, and password validation. **This release is fully backward compatible** — no breaking changes.

### What's New

#### Modular Agent Architecture
The Windows PowerShell agent (`CBUP-Agent.ps1`) has been completely refactored from a single monolithic script into 15 focused modules loaded via dot-sourcing:

| Category | Modules |
|----------|---------|
| **Core** | CBUP-Logging, CBUP-Registry, CBUP-API, CBUP-Registration, CBUP-Service |
| **Discovery** | CBUP-Discovery |
| **Telemetry** | CBUP-Telemetry |
| **EDR** | CBUP-EDR-Process, CBUP-EDR-Service, CBUP-EDR-Port, CBUP-EDR-Autorun, CBUP-EDR-Vulnerability, CBUP-EDR-Full |
| **C2** | CBUP-C2Commands |
| **Signing** | CBUP-Signature |

The main `CBUP-Agent.ps1` is now a 336-line entry point that loads modules from the `agent/modules/` directory.

#### Company-Specific Signature System
New `CBUP-Signature.ps1` module providing per-tenant cryptographic fingerprinting:
- SHA256 fingerprints derived from tenant registration tokens
- Registry-based persistence at `HKLM:\SOFTWARE\CBUP\Signature`
- Runtime signature verification on agent startup
- Automatic embedding during EXE build via `build-exe.ps1`
- Tamper detection: agent refuses to start if signature doesn't match

### Security Fixes

The following 7 bugs were fixed in the Windows PowerShell agent. Several of these could cause agent crashes or silent failures in production:

1. **NullReferenceException in Process Scan** (Critical)
   - **Impact**: Agent crash during EDR process scanning when `ExecutablePath` is null (common for system processes)
   - **Root Cause**: Missing null guard before `.StartsWith()` method call on `$proc.ExecutablePath`
   - **Fix**: Added `$proc.ExecutablePath -and` null coalescing before path validation

2. **Missing Type Annotation** (Medium)
   - **Impact**: Potential parameter binding errors in C2 command handler
   - **Root Cause**: `[hashtable]` parameter type annotation was missing from command handler function
   - **Fix**: Added explicit `[hashtable]` type annotation for the `$commandData` parameter

3. **Pipeline Expression in Hashtable** (High)
   - **Impact**: Uptime telemetry field reported as empty/incorrect
   - **Root Cause**: Pipeline expression (`| Select-Object -ExpandProperty`) used inside a hashtable literal, which is invalid PowerShell syntax
   - **Fix**: Replaced with direct `.TotalSeconds` property access

4. **Missing Math Expression** (Low)
   - **Impact**: File size error message displayed raw expression text instead of calculated value
   - **Root Cause**: `$([math]::Round(...))` string interpolation was not evaluated in the error message
   - **Fix**: Corrected string interpolation syntax for math expression

5. **Password Policy Variable Error** (High)
   - **Impact**: Vulnerability scan password policy check failed or reported incorrect results
   - **Root Cause**: Reference to undefined `$maxLen` variable; broken double `-ne` condition
   - **Fix**: Removed undefined variable reference and corrected the conditional logic

6. **Unsafe Type Cast** (High)
   - **Impact**: Agent crash during password length validation when value is non-numeric
   - **Root Cause**: `[int]` cast applied to string values that may not be integers (e.g., "Unknown")
   - **Fix**: Reordered validation to check for non-integer values before attempting cast

7. **Over-escaped Regex Patterns** (Critical)
   - **Impact**: EDR process scan and autorun scan failed to detect suspicious paths — regex patterns never matched
   - **Root Cause**: Double backslash escaping (`\\\\Temp` instead of `\\Temp`) caused patterns to look for literal double backslashes
   - **Fix**: Corrected regex escaping in CBUP-EDR-Process.ps1 and CBUP-EDR-Autorun.ps1

### Breaking Changes

**None.** This release is fully backward compatible:
- All existing API endpoints remain unchanged
- Agent registration and heartbeat protocol unchanged
- No database schema changes
- No changes to the web UI (Next.js/React)
- The monolith backup (`CBUP-Agent.ps1.bak`) is preserved

### Upgrade Instructions

#### For the CBUP Server (Platform)

```bash
# Using the management CLI (recommended)
cbup update

# Manual update
cd /opt/cbup
sudo git pull origin main
bun install
bun run build
sudo systemctl restart cbup
```

#### For Windows Agents (PowerShell)

Agents will need to be redeployed with the new modular architecture:

```powershell
# Option 1: Download and run the updated agent (one-liner)
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-WebRequest -Uri 'https://YOUR-PORTAL/api/agents/install-script?platform=windows&token=TENANT_TOKEN' -OutFile 'CBUP-Agent.ps1'; .\CBUP-Agent.ps1 -ServerUrl 'https://YOUR-PORTAL' -Token TENANT_TOKEN -Install
```

**Note**: The modular agent requires the `modules/` directory to be present alongside `CBUP-Agent.ps1`. When deploying via the portal download, the modules are bundled automatically. For manual deployments, ensure the entire `agent/` directory is copied.

#### For Windows Agents (EXE)

Rebuild and redeploy signed EXEs:

```powershell
# Download updated build script with signature
Invoke-WebRequest -Uri 'https://YOUR-PORTAL/api/agents/install-script?platform=windows-exe&token=TENANT_TOKEN' -OutFile 'build-exe.ps1'

# Build new signed EXE
.\build-exe.ps1

# Deploy to endpoints (via GPO, SCCM, or manual)
Copy-Item .\dist\CBUP-Agent.exe -Destination "\\target-endpoint\C$\Program Files\CBUP\Agent\"
```

#### For Linux Agents

The Linux agent (`cbup-agent-linux.sh`) is unchanged in v2.1.0 — no action required. Linux agents will continue to operate normally.

#### For Docker Agents

Pull the updated image:

```bash
docker pull cbup/agent:2.1.0
docker stop cbup-agent && docker rm cbup-agent
docker run -d --name cbup-agent --restart unless-stopped \
  -e CBUP_SERVER_URL="https://YOUR-PORTAL" \
  -e CBUP_TOKEN="TENANT_TOKEN" \
  cbup/agent:2.1.0
```

### Files Changed

| File | Change |
|------|--------|
| `agent/CBUP-Agent.ps1` | Rewritten as 336-line modular entry point |
| `agent/CBUP-Agent.ps1.bak` | Preserved as backup of pre-v2.1.0 monolith |
| `agent/CBUP-Agent-Tray.ps1` | Version bump to 2.1.0 |
| `agent/build-exe.ps1` | Version bump to 2.1.0, signature embedding |
| `agent/modules/` | New directory with 15 module files |
| `agent/cbup-agent-linux.sh` | Version bump to 2.1.0 (no code changes) |
| `package.json` | Version bump to 2.1.0 |
| `README.md` | Updated for v2.1.0 features |
| `docs/CHANGELOG.md` | Added v2.1.0 release notes |
| `docs/HOWTO.md` | Added modular agent, signatures, signed EXE guides |
| `docs/TEST_MATRIX.md` | Added signature verification, native testing matrices |
| `docs/PATCHING.md` | New file (this document) |

### Verification After Upgrade

```powershell
# Windows — Verify agent version
Get-Content "C:\Program Files\CBUP\Agent\CBUP-Agent.ps1" | Select-String "AGENT_VERSION"
# Expected: 2.1.0

# Windows — Verify modules directory exists
Test-Path "C:\Program Files\CBUP\Agent\modules"
# Expected: True

# Windows — Verify signature
Get-ItemProperty -Path "HKLM:\SOFTWARE\CBUP\Signature" -ErrorAction SilentlyContinue
```

```bash
# Linux — Verify agent version
grep "AGENT_VERSION" /opt/cbup-agent/cbup-agent.sh
# Expected: 2.1.0
```

---

## Version History

| Version | Date | Type | Summary |
|---------|------|------|---------|
| **2.1.0** | 2026-04-03 | Feature + Bug Fix | Modular agent architecture, company signatures, 7 bug fixes |
| 0.4.2 | 2026-04-03 | Feature | Multi-platform agent downloads, deploy dialog, test matrices |
| 0.4.1 | 2026-04-03 | Bug Fix | Critical `[m[math]` corruption fix in Windows agent |
| 0.4.0 | 2026-04-03 | Feature | Endpoint agent system, multi-tenant, super admin, reports, WebSocket |
| 0.3.0 | 2025-04-03 | Feature | Multi-database support (5 backends), Docker multi-DB |
| 0.2.0 | 2025-01-15 | Feature | Full platform rebrand, 7 views, pricing, installer |
| 0.1.0 | 2025-01-14 | Initial | Project scaffold with Next.js 16, shadcn/ui |

---

## Security Patch Urgency

| Severity | Description | Recommended Action |
|----------|-------------|-------------------|
| **Critical** | Active exploitation, data exposure risk, agent crash | Apply within 24 hours |
| **High** | Significant vulnerability, feature failure | Apply within 72 hours |
| **Medium** | Potential risk under specific conditions | Apply within 1 week |
| **Low** | Best practice improvement, minor fix | Apply during next scheduled update |

See [docs/CHANGELOG.md](CHANGELOG.md) for the full version history and [docs/TEST_MATRIX.md](TEST_MATRIX.md) for platform compatibility.
