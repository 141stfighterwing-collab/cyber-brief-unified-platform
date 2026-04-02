# Changelog

All notable changes to Cyber Brief Unified Platform (CBUP) are documented in this file. This project follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to the specified versioning scheme.

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

### v0.3.0 (Planned)
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
- PostgreSQL and MySQL support
- WebSocket real-time alert streaming
- API key management
- Rate limiting
- Comprehensive API documentation (OpenAPI/Swagger)

### v2.0.0 (Planned)
- SIEM integration (Splunk, Elastic, Sentinel)
- Vulnerability scanner integration (Nessus, OpenVAS)
- Custom threat feed aggregation
- Multi-language support (i18n)
- Mobile-responsive PWA
