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

## v2.1.1 — 2026-04-05

### Summary

v2.1.1 is a **critical hotfix** that resolves a parse error in the Windows EXE build script download endpoint. All Windows EXE agent deployments from company portals were completely broken in v2.1.0 due to a PowerShell script injection ordering bug. This patch also hardens injected variable values against single-quote string injection. **Apply immediately if you are using the `windows-exe` agent platform.**

### What's Fixed

#### 1. Critical: `build-exe.ps1` Parse Error (All Windows EXE Deployments Broken)

**Impact**: When any user downloaded `build-exe.ps1` from their company portal (`/api/agents/install-script?platform=windows-exe&token=...`), the resulting script would fail immediately with:

```
At build-exe.ps1:48 char:1
+ [CmdletBinding()]
+ ~~~~~~~~~~~~~~~~~
Unexpected attribute 'CmdletBinding'.

At build-exe.ps1:49 char:1
+ param(
+ ~~~~~
Unexpected token 'param' in expression or statement.
```

**Root Cause**: The `install-script/route.ts` API endpoint for `windows-exe` prepended PowerShell variable assignments (`$CBUP_EXE_COMPANY = '...'`, `$CBUP_SIGNATURE_COMPANY = '...'`, etc.) **before** the script's `[CmdletBinding()]` and `param()` block. PowerShell requires these attributes to be the first non-comment executable statements — any code before them causes a parse error.

**Fix**: The injection logic was refactored with a two-pass approach:
1. **Pass 1**: Prepend only comment-based headers (`#` lines) before the script — these are safe before `[CmdletBinding()]`
2. **Pass 2**: Use parenthesis-balanced string scanning to locate the end of the `param()` block, then insert variable assignments **after** it

The parenthesis-balanced scanner properly handles nested parentheses within `[Parameter(HelpMessage="...")]` attributes in the param block.

**Affected Endpoint**: `GET /api/agents/install-script?platform=windows-exe`

#### 2. Hardening: Single-Quote Escaping

Company names or signature values containing single quotes (e.g., `O'Brien's Security`, `L'avion`) would break the downloaded PowerShell script syntax. All dynamically injected values now have single quotes escaped using PowerShell's `''` escape sequence.

**Affected Functions**: `formatSignatureAsPsVariables()`, `windows-exe` case in `GET /api/agents/install-script`

### Breaking Changes

**None.** This is a bug-fix-only release with no API changes, schema changes, or UI modifications. The fix is transparent to all consumers — downloaded scripts will simply work correctly.

### Files Changed

| File | Change |
|------|--------|
| `src/app/api/agents/install-script/route.ts` | Fixed variable injection ordering for `windows-exe` platform |
| `src/app/api/agents/install-script/route.ts` | Added single-quote escaping in `formatSignatureAsPsVariables()` |
| `docs/CHANGELOG.md` | Added v2.1.1 release notes |
| `docs/PATCHING.md` | Added v2.1.1 patch notes (this section) |

### Upgrade Instructions

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

After upgrading, existing `build-exe.ps1` downloads will work correctly. Users who previously downloaded a broken script should re-download it from their company portal.

### Verification

```powershell
# 1. Re-download the build script from your portal
Invoke-WebRequest -Uri 'http://YOUR-PORTAL/api/agents/install-script?platform=windows-exe&token=TENANT_TOKEN' -OutFile 'build-exe.ps1'

# 2. Verify the script parses correctly (should produce NO errors)
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$PWD\build-exe.ps1", [ref]$null, [ref]$errors)
if ($errors.Count -eq 0) { Write-Host "[OK] Script parses successfully" -ForegroundColor Green } else { Write-Host "[FAIL] Parse errors:" $errors -ForegroundColor Red }

# 3. Run the build
.\build-exe.ps1

# 4. Verify EXE was created
Test-Path .\dist\CBUP-Agent.exe
# Expected: True
```

---

## v2.2.0 — 2026-04-05

### Summary

v2.2.0 is a **major security overhaul** release addressing 13 identified security vulnerabilities (7 Critical, 4 High, 2 Medium). A comprehensive security audit of the entire CBUP platform was conducted, resulting in 11 fixes across 13 files. All changes are **fully backward compatible** — no breaking changes. This release also adds new security libraries, authentication middleware, and enhanced password enforcement.

### What's Changed

#### Security Fixes (11 of 13 Vulnerabilities Addressed)

| # | ID | Severity | Category | Status |
|---|-----|----------|----------|--------|
| 1 | VULN-001 | Critical | Authentication | ✅ Fixed |
| 2 | VULN-002 | Critical | C2 Hardening | ✅ Fixed |
| 3 | VULN-003 | Critical | C2 Hardening | ✅ Fixed |
| 4 | VULN-004 | Critical | Credential Storage | ✅ Fixed |
| 5 | VULN-005 | Critical | Credential Storage | ✅ Fixed |
| 6 | VULN-006 | Critical | Integrity Verification | ✅ Fixed |
| 7 | VULN-007 | Critical | Cryptography | ✅ Fixed |
| 8 | VULN-008 | High | Rate Limiting | ✅ Fixed |
| 9 | VULN-009 | High | Authentication | ✅ Fixed |
| 10 | VULN-010 | High | Input Validation | ✅ Fixed |
| 11 | VULN-011 | High | TLS Security | ✅ Fixed |
| 12 | VULN-012 | Medium | Supply Chain | ⚠️ Documented |
| 13 | VULN-013 | Medium | Container Security | ⚠️ Documented |

#### New Libraries & Middleware

| Component | File | Purpose |
|-----------|------|---------|
| Rate Limiting Library | `src/lib/rate-limit.ts` | In-memory sliding-window rate limiter with per-IP tracking |
| Authentication Middleware | `src/lib/auth-check.ts` | Admin auth validation (header, bearer, cookie) |

### Security Fixes Detail

#### Critical Fixes

1. **VULN-001: Unauthenticated Agent Download Endpoints**
   - Added admin authentication to `/api/agents/download-exe` and `/api/agents/download-build`
   - Previously any anonymous user could download the full agent source code

2. **VULN-002: Arbitrary Code Execution via C2**
   - Implemented PowerShell AST-based command allowlisting for `RUN_CUSTOM_SCRIPT` C2 command
   - Over 60 safe cmdlets explicitly permitted; non-whitelisted commands rejected

3. **VULN-003: Arbitrary File Exfiltration**
   - Added path blocklist to `COLLECT_FILE` C2 command (credentials, private keys, registry hives)
   - Maximum file size reduced from 50MB to 10MB

4. **VULN-004: Plaintext Password Storage**
   - Passwords now hashed with Node.js `crypto.scryptSync` (16-byte random salt, `salt:hash` format)
   - Backward compatible with existing login flow

5. **VULN-005: Plaintext Registry Token Storage**
   - Agent auth tokens in Windows registry now encrypted with DPAPI

6. **VULN-006: Agent Update Without Integrity Verification**
   - `UPDATE_AGENT` C2 command now verifies SHA256 hash of downloaded update file

7. **VULN-007: Weak Cryptographic Signature Scheme**
   - Replaced SHA256 with HMAC-SHA256 using 32-byte cryptographically random server-side secret

#### High Severity Fixes

8. **VULN-008: No Rate Limiting**
   - Sliding-window rate limiter on 5 endpoints (install-script: 30/5min, downloads: 20/5min, signup: 5/min, commands: 20/min)

9. **VULN-009: Unauthenticated Command Creation**
   - Added admin auth to `POST /api/agents/commands`

10. **VULN-010: Missing Input Validation**
    - Strict validation on install-script endpoint (platform whitelist, token regex, companyName sanitization)

11. **VULN-011: No TLS Certificate Pinning**
    - Optional certificate thumbprint pinning via `PinnedCertThumbprint` parameter (backward compatible)

#### Documented Limitations (Not Fixed)

12. **VULN-012 (Medium)**: ps2exe module installation does not verify module hash. Recommendation: Pin module version.
13. **VULN-013 (Medium)**: Docker Compose mounts `/proc` and `/sys` read-only. Recommendation: Add seccomp profile.

### Breaking Changes

**None.** All changes are fully backward compatible:
- Agent signature scheme uses HMAC-SHA256 with SHA256 fallback on older agents
- DPAPI encryption is applied during token registration; existing plaintext tokens continue to work until re-registered
- Rate limiting returns `429 Too Many Requests` (clients should handle gracefully)
- TLS pinning is opt-in via configuration parameter

### Files Changed

| File | Change |
|------|--------|
| `src/lib/rate-limit.ts` | **New** — Sliding-window rate limiting library |
| `src/lib/auth-check.ts` | **New** — Admin authentication middleware |
| `src/app/api/agents/download-exe/route.ts` | Added admin authentication guard |
| `src/app/api/agents/download-build/route.ts` | Added admin authentication guard |
| `src/app/api/agents/commands/route.ts` | Added admin authentication to POST handler |
| `src/app/api/agents/install-script/route.ts` | Added input validation, rate limiting |
| `src/app/api/auth/signup/route.ts` | Password hashing, strength enforcement, email validation |
| `agent/modules/CBUP-C2Commands.ps1` | AST-based command allowlisting, SHA256 update verification, file collection hardening |
| `agent/modules/CBUP-Registration.ps1` | DPAPI encryption for registry tokens |
| `agent/modules/CBUP-API.ps1` | TLS certificate pinning, HMAC-SHA256 signature verification |
| `agent/modules/CBUP-Signature.ps1` | HMAC-SHA256 signature upgrade with SHA256 fallback |
| `agent/CBUP-Agent.ps1` | Version bump to 2.2.0 |
| `package.json` | Version bump to 2.2.0 |

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

After upgrading, all security controls are active immediately. Existing user passwords will be hashed on next login. Agents will need to be redeployed to benefit from client-side security fixes.

#### For Agents

Redeploy agents to receive client-side security fixes (DPAPI token encryption, C2 hardening, TLS pinning):

```powershell
# Windows — Download and re-run the updated agent
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-WebRequest -Uri 'https://YOUR-PORTAL/api/agents/install-script?platform=windows&token=TENANT_TOKEN' -OutFile 'CBUP-Agent.ps1'; .\CBUP-Agent.ps1 -ServerUrl 'https://YOUR-PORTAL' -Token TENANT_TOKEN -Install
```

```bash
# Linux
curl -fsSL 'https://YOUR-PORTAL/api/agents/install-script?platform=linux&token=TENANT_TOKEN' | sudo bash
```

### Verification

After upgrading, verify security controls are active:

```bash
# 1. Verify server version
cbup status
# Expected version: 2.2.0

# 2. Verify rate limiting is active (should return 429 after limit)
for i in $(seq 1 35); do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/agents/install-script; done
# Expected: mix of 200 responses followed by 429

# 3. Verify download endpoints require authentication
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/agents/download-exe
# Expected: 401 or 403

# 4. Verify command creation requires authentication
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/agents/commands
# Expected: 401 or 403

# 5. Verify new library files exist
ls -la src/lib/rate-limit.ts src/lib/auth-check.ts
# Expected: both files present
```

```powershell
# Windows — Verify agent version
Get-Content "C:\Program Files\CBUP\Agent\CBUP-Agent.ps1" | Select-String "AGENT_VERSION"
# Expected: 2.2.0

# Windows — Verify DPAPI-encrypted token in registry
Get-ItemProperty -Path "HKLM:\SOFTWARE\CBUP" -Name "EncryptedToken" -ErrorAction SilentlyContinue
# Expected: EncryptedToken value present (binary data)
```

---

## Version History

| Version | Date | Type | Summary |
|---------|------|------|---------|
| **2.2.0** | 2026-04-05 | Security Overhaul | Comprehensive security audit: 13 vulnerabilities addressed, 11 fixed across 13 files |
| **2.1.1** | 2026-04-05 | Critical Hotfix | Fixed `build-exe.ps1` parse error for all Windows EXE deployments |
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
