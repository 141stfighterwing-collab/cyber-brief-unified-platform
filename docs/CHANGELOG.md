# Changelog

All notable changes to Cyber Brief Unified Platform (CBUP) are documented in this file. This project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to the specified versioning scheme.

---

## [0.4.1] - 2026-04-03

### Fixed

#### Endpoint Agent — Critical Script Corruption Fix
- **Windows PowerShell Agent** (`agent/CBUP-Agent.ps1`): Fixed 22 instances of corrupted `[m[math]` type references that should have been `[math]`. This corruption was introduced by a malformed text replacement in the original commit and caused **fatal parse errors** on every agent module that performs numeric calculations. Affected functions include:
  - `Get-SystemDiscoveryData` — RAM (line 438), disk size calculations (lines 483–484)
  - `Get-TelemetryData` — CPU average (line 539), memory metrics (lines 543–545, 550, 552), disk space (lines 560, 563–566), top process CPU/memory (lines 600–601, 615–616), uptime (line 633)
  - `Invoke-EDRProcessScan` — process CPU and memory calculations (lines 713–714)
  - Command file-size validation (line 1521)
- The backup file `agent/CBUP-Agent.ps1.bak` was also corrected and preserved as the known-good reference.

### Changed
- Agent version bumped from **2.0.0** to **2.0.1** across all agent files:
  - `agent/CBUP-Agent.ps1`
  - `agent/CBUP-Agent.ps1.bak`
  - `agent/CBUP-Agent-Tray.ps1`
  - `agent/build-exe.ps1`
  - `agent/cbup-agent-linux.sh`

---

## [0.4.0] - 2026-04-03

### Added

#### Endpoint Agent System (Major Feature)
- **Windows PowerShell Agent** (`agent/CBUP-Agent.ps1`) — 1500+ line production agent with:
  - System discovery (hostname, domain, OS, serial, service tag, BIOS, CPU, RAM, network, disks)
  - Real-time telemetry collection (CPU, memory, disk I/O, network I/O, top processes, TCP connections, uptime)
  - 5 EDR scan types: process analysis, service enumeration, port scan, autorun/persistence, vulnerability assessment
  - Command & Control (C2) protocol with command polling and result reporting
  - Windows service installation with registry persistence
  - Gzip compression for large payloads
  - Exponential backoff retry logic with TLS validation
- **Linux Ubuntu Agent** (`agent/cbup-agent-linux.sh`) — 1050+ line Bash agent with:
  - Full system discovery via dmidecode, /proc filesystem, lshw
  - Real-time telemetry via /proc/stat, /proc/meminfo, /proc/net/dev, /proc/diskstats
  - 5 EDR scans: process, service (systemd), port (ss), autorun (crontab/timers/init.d), vulnerability (apt/SSH/firewall/SUID)
  - C2 protocol identical to Windows agent
  - Systemd service with security hardening and auto-restart
  - Compatible with Ubuntu 18.04+ and Debian 10+
- **Windows System Tray App** (`agent/CBUP-Agent-Tray.ps1`) — GUI system tray application with:
  - Dynamic status icons (green/yellow/red/gray) with shield overlay
  - Right-click context menu: status, open dashboard, run EDR scan, show logs, restart agent
  - Balloon tip notifications with cooldown for agent events
  - 10-second polling timer for status updates
- **Windows EXE Build Script** (`agent/build-exe.ps1`) — Compiles PS1 to standalone .exe via ps2exe
- **Agent Install Script API** (`/api/agents/install-script`) — Serves agent scripts for download

#### Multi-Tenant Architecture
- New `Tenant` model with name, slug, plan, maxAgents, settings
- New `TenantUser` model for user-tenant membership with role (owner/admin/analyst/member)
- Tenant-scoped agent assignment with `tenantId` field on agents, alerts, and reports
- **Tenant Management APIs**: Create, list, get, update, soft-delete tenants
- **Agent Assignment API**: Assign/reassign agents between tenants

#### Super Admin Console
- New `role` field on User model: `user`, `admin`, `super_admin`
- **Super Admin View** (`/components/admin/super-admin-view.tsx`) — 750+ line management dashboard:
  - Platform-wide statistics (tenants, users, agents, alerts)
  - Overview tab with pie/bar charts and health metrics
  - Tenants tab with CRUD table and create dialog
  - All Endpoints tab with cross-tenant filtered table
  - Users tab with role management
  - Activity Log tab with filtered timeline
- **Super Admin APIs**: Platform stats, cross-tenant agents, user management, role assignment
- Role-based navigation: Admin and Reports nav items only visible to authorized users

#### Security Reports
- New `SecurityReport` model with type, status, data, summary, agentIds
- **5 Report Types**: Endpoint Health, EDR Scan Summary, Vulnerability Assessment, Compliance, Full Audit
- **Reports View** (`/components/reports/reports-view.tsx`) — 550+ line interface:
  - Report type cards with descriptions
  - Generate Report dialog with scope selection
  - Reports table with status indicators
  - Detailed report view with radar chart, risk scores, compliance status, findings with recommendations
- **Reports APIs**: Generate, list, get, delete, PDF placeholder

#### Live WebSocket Infrastructure
- **WebSocket Hub** (`src/lib/websocket.ts`) — Singleton WebSocket server with:
  - Tenant-scoped broadcasting (users only see their tenant's data)
  - Super Admin sees all tenants' events
  - 7 event types: telemetry, command_status, edr_scan_progress, agent_online/offline, alert_new, report_generated
  - Message replay queue (1000 messages) for reconnection
  - Connection management with client tracking
- **WebSocket Route** (`/api/ws`) — Connection endpoint and event type documentation
- **Heartbeat Integration** — Agent heartbeats now broadcast real-time telemetry to connected WebSocket clients

#### UI Enhancements
- Live indicator in navbar and agents view (green pulsing dot for WebSocket connected)
- Tenant selector dropdown in navbar for multi-tenant switching
- Platform Health section in dashboard for super_admin users
- Recent Reports section in dashboard for admin users
- Tenant filter in agents view for cross-tenant management
- Updated Deploy Agent dialog with Linux and Windows EXE installation instructions

#### Database Schema Updates
- `Tenant` model (id, name, slug, description, plan, maxAgents, settings, active)
- `TenantUser` model (tenantId, userId, role)
- `User` model enhanced with: role, avatar, settings fields
- `Agent` model enhanced with: tenantId, tags, groups, notes fields
- `Alert` model enhanced with: agentId, tenantId, resolved fields
- `SecurityReport` model (id, tenantId, title, type, status, data, summary, agentIds)

### Changed
- Version bumped from 0.3.0 to 0.4.0
- Zustand store updated with: admin/reports views, user role, tenant state, live telemetry state
- Navbar updated with role-gated navigation items and tenant selector
- All 31 API routes verified compiling with zero errors

---

## [0.3.0] - 2025-04-03

### Added

#### Multi-Database Support (Major Feature)
- **5 database backends** now supported: SQLite, MySQL, PostgreSQL, MongoDB, and SQL Server
- New unified database provider layer (`src/lib/db-provider.ts`) with automatic routing based on `DATABASE_PROVIDER` environment variable
- Prisma-compatible adapter for all SQL databases (SQLite, MySQL, PostgreSQL)
- Native MongoDB driver adapter (`src/lib/mongodb.ts`) with full CRUD operations for all 4 collections
- MySQL-specific Prisma schema (`prisma/schema.mysql.prisma`) with proper `@db.VarChar`, `@db.DateTime`, `@db.Text` annotations
- PostgreSQL-specific Prisma schema (`prisma/schema.postgresql.prisma`) with `@db.VarChar`, `@db.Timestamp` annotations
- Zero code changes required in API routes — all 6 endpoints work transparently with any database provider
- New `/api/db-status` endpoint returning provider name, connection status, table names, and record counts

#### Docker Multi-Database Deployment
- `docker-compose.mysql.yml` — MySQL 8.0 + phpMyAdmin (port 8081) with healthchecks and automatic database provisioning
- `docker-compose.postgresql.yml` — PostgreSQL 16-alpine + pgAdmin (port 8082) with healthchecks and connection pooling
- `docker-compose.mongodb.yml` — MongoDB 7 + Mongo Express (port 8083) with authentication and index creation
- `docker-compose.mssql.yml` — SQL Server 2022 Express with sqlcmd healthcheck validation
- Default credentials pre-configured for all database containers (documented in `.env.example`)
- Each database compose file includes a management UI (phpMyAdmin, pgAdmin, Mongo Express) for easy administration
- Updated Dockerfile with `DATABASE_URL` build argument and `DATABASE_PROVIDER` runtime environment variable

#### Install Script Enhancements
- Interactive database selection menu during installation (`install.sh`)
- New `--db <provider>` flag for non-interactive database selection (e.g., `./install.sh --docker --db mysql`)
- Automatic database provisioning: creates databases, users, grants, and tables for each provider
- Automatic schema selection: copies the correct Prisma schema file based on chosen database
- Default credentials configured for all database backends
- New `cbup db-info` CLI command showing provider, connection details, table list, record counts, and database size
- Updated `cbup doctor` with database connectivity checks per provider type
- Updated `cbup backup` with provider-specific dump tools (mysqldump, pg_dump, mongodump, sqlcmd)
- Updated `cbup restore` with provider-specific restore tools
- Updated `cbup update` to skip `db:push` for MongoDB deployments
- Install script grew from 1,727 to 2,763 lines with full multi-database orchestration

#### Screenshots & Visual Validation
- Playwright-based screenshot capture system (`scripts/capture-screenshots.ts`)
- 16 full-page screenshots covering all platform views at 2x resolution (2880×1800)
- Landing page (hero, features, pricing, sample brief, testimonials)
- Authentication (login, signup with tier selection)
- Dashboard (stats, recent alerts, quick actions)
- Alerts view (18 cybersecurity alerts with severity filtering)
- Briefs view (full daily intelligence brief)
- Monitoring view (Recharts dashboards)
- Workflow view (Kanban board with task management)
- API endpoint responses (db-status, alerts, stats, briefs)

#### Configuration
- New `.env.example` file with templates for all 5 database providers
- Environment variables: `DATABASE_PROVIDER` (sqlite|mysql|postgresql|mongodb|mssql) and `DATABASE_URL`

### Changed
- Version bumped from 0.2.0 to 0.3.0
- `src/lib/db.ts` now delegates to `db-provider.ts` (backward-compatible import path preserved)
- Install script `--help` updated with database options
- Docker compose default file explicitly labeled as SQLite configuration

---

## [0.2.0] - 2025-01-15

### Added

#### Product & Branding
- Renamed platform from "Morning Cyber Brief" to **Cyber Brief Unified Platform (CBUP)**
- New tagline: "One platform. Every threat covered."
- New logo abbreviation: CBUP
- Updated all branding across navbar, footer, hero, testimonials, auth, and metadata

#### Features
- **7 Application Views**:
  - Landing page with hero, features, pricing, sample preview, testimonials
  - Authentication (Sign Up / Sign In with tier selection)
  - Dashboard with stats cards, recent alerts, quick actions, trend chart
  - Alert management (18 realistic cybersecurity alerts, severity filtering)
  - Daily brief display (5-section professional layout)
  - Monitoring dashboard (line, bar, and donut charts via Recharts)
  - Workflow Kanban board (4 columns, task CRUD, priority/assignee tracking)

#### Security Content
- 18 pre-loaded alerts covering: CVEs, zero-days, phishing, ransomware, APTs, supply chain attacks, data breaches
- Full daily brief sample with: Top Threats, Vulnerability Watch, Industry Alerts, Recommended Actions, Threat Intelligence Summary
- 10 pre-loaded workflow tasks with realistic cybersecurity remediation actions

#### Pricing Tiers
- **Free** ($0/mo): 1 user, headline alerts, weekly brief
- **Starter** ($29/mo): 5 users, daily brief, workflow, basic monitoring
- **Pro** ($99/mo): 25 users, real-time alerts, compliance, API access
- **Enterprise** (Custom): Unlimited users, on-prem, SIEM integration, SLA

#### Infrastructure
- 1-click install script (`install.sh`) supporting bare-metal and Docker deployments
- Management CLI (`cbup`) with 12 commands: start, stop, restart, status, logs, update, backup, restore, reset-db, doctor, shell, uninstall
- Systemd service with security hardening (NoNewPrivileges, ProtectSystem, PrivateTmp)
- Docker support with Dockerfile, docker-compose.yml, and healthchecks
- Firewall auto-configuration (UFW and firewalld)
- Automatic backup with 30-backup rotation

#### Database
- Prisma ORM with SQLite
- 4 data models: User, Alert, Brief, Task
- 6 REST API endpoints: auth/signup, alerts, tasks CRUD, briefs/latest, dashboard/stats

#### Documentation
- Comprehensive README with architecture diagram, API reference, project structure
- [docs/DATABASES.md](DATABASES.md) — Full database schema, ERD, backup/restore procedures
- [docs/HOWTO.md](HOWTO.md) — Installation, configuration, SSL, security hardening, troubleshooting
- [docs/FAQ.md](FAQ.md) — 30+ frequently asked questions
- [docs/CONTRIBUTING.md](CONTRIBUTING.md) — Code contribution guidelines
- [docs/CHANGELOG.md](CHANGELOG.md) — This file

#### Tech Stack
- Next.js 16 with App Router
- TypeScript 5
- Tailwind CSS 4 with shadcn/ui (New York style)
- Zustand for state management
- Recharts for monitoring dashboards
- Framer Motion for animations
- Custom dark emerald cybersecurity theme

---

## [0.1.0] - 2025-01-14

### Added
- Initial project scaffold with Next.js 16, TypeScript, Tailwind CSS 4
- shadcn/ui component library (complete set)
- Prisma ORM configuration with SQLite
- Development tooling (ESLint, PostCSS)
- Base layout with Geist font family
- Git repository initialized

---

## Versioning Policy

### Semantic Versioning

CBUP follows [Semantic Versioning 2.0.0](https://semver.org/):

| Level | When | Examples |
|-------|------|----------|
| **MAJOR** | Breaking changes | Database schema changes that require migration, API removal, UI overhaul |
| **MINOR** | New features (backward compatible) | New views, API endpoints, integrations, configuration options |
| **PATCH** | Bug fixes (backward compatible) | Security patches, UI fixes, performance improvements, docs |

### Pre-Release Versions

Pre-release versions use the format `MAJOR.MINOR.PATCH-rc.N`:
- `1.0.0-rc.1` — First release candidate
- `1.0.0-rc.2` — Second release candidate (bug fixes from rc.1)
- `1.0.0` — Final release

### Development Versions

Development builds are versioned as `MAJOR.MINOR.PATCH-dev.N` and should never be used in production.

---

## Patching Guide

### How to Apply Updates

#### Method 1: Management CLI (Recommended)

```bash
# The update command automatically:
# 1. Creates a database backup
# 2. Pulls the latest code from git
# 3. Installs dependencies
# 4. Pushes any schema changes
# 5. Rebuilds the production bundle
# 6. Restarts the service
cbup update
```

#### Method 2: Manual Update

```bash
# 1. Backup first
cbup backup

# 2. Pull the latest code
cd /opt/cbup
git fetch origin
git checkout v0.3.0    # or: git pull origin main

# 3. Install any new dependencies
bun install

# 4. Apply database migrations (if needed)
bun run db:push         # For simple schema additions
# or
bun run db:migrate deploy  # For production migrations with history

# 5. Rebuild
bun run build

# 6. Restart
sudo systemctl restart cbup
```

### Checking Your Current Version

```bash
# Via CLI
cbup status

# Via package.json
cat /opt/cbup/package.json | grep version

# Via git
cd /opt/cbup && git describe --tags
```

### Downgrading

If an update causes issues:

```bash
# 1. Restore the database backup from before the update
cbup restore /var/backups/cbup/cbup-backup-<timestamp>.db.gz

# 2. Checkout the previous version
cd /opt/cbup
git checkout v0.2.0    # The version you want to downgrade to

# 3. Reinstall dependencies and rebuild
bun install
bun run build

# 4. Restart
sudo systemctl restart cbup
```

### Security Patch Urgency

| Severity | Description | Recommended Action |
|----------|-------------|-------------------|
| **Critical** | Active exploitation, data exposure risk | Apply within 24 hours |
| **High** | Significant security vulnerability | Apply within 72 hours |
| **Medium** | Potential risk under specific conditions | Apply within 1 week |
| **Low** | Best practice improvement | Apply during next scheduled update |

Security patches will always be released as PATCH version increments (e.g., `0.2.0` → `0.2.1`) to ensure backward compatibility.

---

## Release Roadmap

### v0.3.1 (Planned)
- Password hashing with bcrypt
- Email notification system
- User session management via NextAuth.js
- Alert subscription preferences
- Brief delivery scheduling

### v0.4.0 (Planned)
- Role-based access control (RBAC)
- Organization/team management
- Audit logging
- Activity feed per user

### v0.5.0 (Planned)
- PDF export for briefs
- Email digest delivery (SMTP)
- Slack/Teams webhook notifications
- Custom alert rules and filters

### v1.0.0 (Planned)
- WebSocket real-time alert streaming
- API key management
- Rate limiting
- Comprehensive API documentation (OpenAPI/Swagger)
- Advanced RBAC with organization isolation

### v2.0.0 (Planned)
- SIEM integration (Splunk, Elastic, Sentinel)
- Vulnerability scanner integration (Nessus, OpenVAS)
- Custom threat feed aggregation
- Multi-language support (i18n)
- Mobile-responsive PWA
