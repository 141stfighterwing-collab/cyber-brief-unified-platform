# Changelog

All notable changes to the Cyber Brief Unified Platform (CBUP) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.0] - 2026-04-05

### Fixed
- **CRITICAL: DATABASE_URL path resolution** - Fixed `file:./db/custom.db` which resolved to `prisma/db/custom.db` (empty database) instead of the actual database at `db/custom.db`. Changed to `file:../db/custom.db` which correctly resolves from the Prisma schema directory to the project-root `db/` folder. This was the root cause of all "cannot sign in" issues.
- **Default auth mode** - Changed default from 'signup' to 'login' so users see the sign-in form first instead of the signup form.
- **Login error messages** - Improved error handling: "No account found" (404) vs "Invalid password" (401) vs "Rate limited" (429) instead of generic errors.
- **Rate limit error handling** - Frontend now properly handles 429 rate limit responses with a user-friendly message.
- **Login form** - Added visible default admin credentials hint on the login form so users know how to sign in for the first time.
- Removed stale `prisma/db/` directory that was created by incorrect path resolution.

### Security
- Added IP logging to failed login attempts for audit trail.
- Changed "password required" error from 401 to 400 (it's a validation error, not auth failure).

## [2.3.0] - 2026-04-04

### Added
- Default super admin auto-creation on first login (admin@cbup.io / CBUPadmin2024!)
- `ensureDefaultAdmin()` function in signup route seeds admin if no admin exists
- Security changelog documentation (SECURITY-CHANGELOG.md)

### Fixed
- NULL password users can now set their password on first login attempt
- Admin auto-creation fixes null-password seed users by setting default password

## [2.3.0-sec] - 2026-04-04

### Security
- Added `checkAuth()` to 10+ unprotected admin/agent API endpoints
- Implemented timing-safe token comparison (`crypto.timingSafeEqual`) for agent heartbeat, command-result, EDR scan, and commands endpoints
- Added body size limits (1MB) to agent registration, heartbeat, and EDR scan endpoints
- Stripped auth tokens from agent list API responses to prevent token leakage
- Removed all fake/hardcoded data from admin stats dashboard endpoint
- Replaced fake `?role=admin` query param auth with real token-based `checkAuth()` on tenant endpoints

## [2.2.0] - 2026-04-03

### Security
- Fixed 13 vulnerabilities (7 Critical, 4 High, 2 Medium)
- Removed all mock/hardcoded data from company portal views
- Added scrypt password hashing (replacing plaintext storage)
- Added rate limiting on auth endpoints (5 req/min per IP)
- Added email format validation and password strength requirements

### Changed
- Updated seed script to use scrypt hashing for all passwords
- Password format: `salt:hash` (hex-encoded scrypt)

## [2.1.0] - Earlier

### Added
- EDR agent management (registration, telemetry, commands, scans)
- Multi-tenant support
- Security alerts and briefs
- Dashboard with real-time monitoring
- Agent download endpoint for Windows PowerShell install scripts

### Fixed
- Fixed agents.filter crash
- Changed dev port to 3001 to avoid EADDRINUSE conflict
