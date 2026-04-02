# Cyber Brief Unified Platform (CBUP)

<div align="center">

![CBUP Banner](https://img.shields.io/badge/CBUP-Cyber%20Brief%20Unified%20Platform-00C853?style=for-the-badge&logo=shield&logoColor=white)
![Version](https://img.shields.io/badge/version-0.2.0-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Next.js](https://img.shields.io/badge/Next.js-16-black?style=flat-square&logo=next.js)
![TypeScript](https://img.shields.io/badge/TypeScript-5.0-3178C6?style=flat-square&logo=typescript&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat-square&logo=docker&logoColor=white)

**One platform. Every threat covered.**

Unified cybersecurity awareness, real-time alerts, workflow management, and low-level monitoring for companies of any size. Self-hosted and on-prem ready.

[Get Started](#quick-start) · [Features](#features) · [Pricing](#pricing) · [Documentation](#docs/) · [Install Script](#installsh)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [1-Click Installation](#1-click-installation)
- [Docker Deployment](#docker-deployment)
- [Configuration](#configuration)
- [Database](#database)
- [Pricing Tiers](#pricing-tiers)
- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Development](#development)
- [Testing](#testing)
- [Documentation](#documentation)
- [Versioning & Patching](#versioning--patching)
- [License](#license)

---

## Overview

**Cyber Brief Unified Platform (CBUP)** is a comprehensive cybersecurity awareness and monitoring SaaS platform designed for companies that need enterprise-grade security visibility without enterprise-grade complexity. Whether you're a 5-person startup or a 500-person organization, CBUP gives your team the tools to stay informed, respond to threats, and maintain compliance — all from a single, self-hosted platform.

CBUP delivers daily curated threat intelligence briefings, real-time alerting for emerging vulnerabilities and active campaigns, a workflow engine for tracking remediation tasks, and low-level monitoring dashboards for trend analysis and compliance reporting. It is built to run on-premises or in any private cloud environment, giving you full control over your security data.

### Key Design Principles

- **Self-Hosted First**: Your security data stays in your infrastructure. No external dependencies.
- **Low Cost Impact**: Runs on a single server with minimal resources (1 CPU, 2GB RAM minimum).
- **Zero Vendor Lock-In**: Open architecture with SQLite, standard REST APIs, and portable data.
- **Security-Conscious**: Built with defense-in-depth principles, least-privilege services, and hardened configurations.

---

## Features

### Daily Threat Intelligence Brief
- AI-curated morning cybersecurity briefings delivered daily at 6:00 AM
- Sections: Top Threats, Vulnerability Watch, Industry Alerts, Recommended Actions, Threat Intelligence Summary
- Severity-scored items with actionable recommendations
- Historical brief archive with full-text search

### Real-Time Alert Management
- 18+ pre-loaded realistic alerts covering CVEs, zero-days, phishing campaigns, ransomware, APTs, supply chain attacks, and data breaches
- Severity-based filtering: Critical, High, Medium, Low
- Category-based organization: Vulnerability, Malware, Phishing, Ransomware, APT, Supply Chain, Attack, Data Breach, Misconfiguration
- Searchable and expandable alert cards with full descriptions

### Workflow & Task Management
- Kanban-style board with four columns: New, In Progress, Review, Completed
- Task creation with priority levels (Critical, High, Medium, Low) and assignee tracking
- Due date management and status transitions
- Click-to-move task cards between workflow stages

### Monitoring & Analytics
- Interactive threat trend line charts (7-day rolling window)
- Alert distribution bar charts by category
- Severity breakdown donut charts
- System status indicators and health monitoring
- Real-time activity log timeline

### Multi-Tier Access Control
- Free tier for individual practitioners
- Starter tier for small security teams (up to 5 users)
- Pro tier for growing organizations (up to 25 users)
- Enterprise tier with unlimited users, on-prem deployment, and SIEM integration

### On-Premises Deployment
- Single binary deployment via systemd
- Docker container with healthchecks
- Persistent data volumes
- Automated backup and restore
- Firewall auto-configuration

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CBUP Architecture                         │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────────┐  │
│  │  Client   │  │  Client  │  │  Client (Mobile/Desktop) │  │
│  │ (Browser) │  │ (Browser)│  │                          │  │
│  └─────┬─────┘  └────┬─────┘  └──────────┬───────────────┘  │
│        │              │                    │                  │
│        └──────────────┴────────────────────┘                  │
│                       │ HTTP/S                                │
│  ┌────────────────────▼────────────────────────────────────┐  │
│  │                  Reverse Proxy (Caddy)                    │  │
│  │                    Port 80/443                            │  │
│  └────────────────────┬────────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼────────────────────────────────────┐  │
│  │              Next.js 16 Application                       │  │
│  │                   Port 3000                               │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  Frontend (React 19 + Tailwind + shadcn/ui)      │   │  │
│  │  │  Zustand State Management | Recharts             │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │  API Routes (REST)                               │   │  │
│  │  │  /api/auth/signup | /api/alerts                  │   │  │
│  │  │  /api/tasks | /api/briefs | /api/dashboard/stats │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  └────────────────────┬────────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼────────────────────────────────────┐  │
│  │              Prisma ORM                                  │  │
│  └────────────────────┬────────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼────────────────────────────────────┐  │
│  │              SQLite Database                              │  │
│  │              /var/lib/cbup/cbup.db                        │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Next.js (App Router) | 16.x |
| Language | TypeScript | 5.x |
| Runtime | Bun | 1.2+ |
| UI Library | shadcn/ui (New York) | Latest |
| CSS Framework | Tailwind CSS | 4.x |
| State Management | Zustand | 5.x |
| Database | SQLite via Prisma ORM | 6.x |
| Charts | Recharts | 2.x |
| Animations | Framer Motion | 12.x |
| Forms | React Hook Form + Zod | 7.x / 4.x |

---

## Quick Start

### Prerequisites

- **Bun** 1.0+ — [Install Bun](https://bun.sh/)
- **Git** — for cloning the repository
- **Node.js** 20+ (alternative to Bun)

### Install & Run

```bash
# Clone the repository
git clone https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

# Install dependencies
bun install

# Set up database
bun run db:push

# Start development server
bun run dev
```

The application will be available at `http://localhost:3000`.

### Production Build

```bash
# Build for production
bun run build

# Start production server
bun run start
```

---

## 1-Click Installation

The included `install.sh` script automates the entire installation process — from system prerequisites to a running production service.

### Quick Install (Bare Metal)

```bash
# Make executable and run
chmod +x install.sh
sudo ./install.sh
```

### Docker Install

```bash
sudo ./install.sh --docker
```

### Non-Interactive (for CI/CD or scripting)

```bash
sudo ./install.sh --yes --port 8080
```

### Custom Options

```bash
# Install from a specific branch
sudo ./install.sh --branch release/v1.0

# Use a custom port
sudo ./install.sh --port 8443

# Uninstall completely
sudo ./install.sh --uninstall
```

### What the installer does:

1. Detects OS and architecture (Ubuntu, Debian, CentOS, RHEL, Fedora, Amazon Linux)
2. Installs Bun runtime (if not present)
3. Installs system prerequisites (curl, git, build-essential, openssl-dev)
4. Clones/copies application files to `/opt/cbup`
5. Installs Node.js dependencies
6. Initializes the SQLite database with Prisma schema
7. Builds the Next.js production bundle
8. Creates a systemd service with security hardening
9. Configures firewall rules (UFW or firewalld)
10. Installs the `cbup` management CLI

### Management CLI

After installation, use the `cbup` command to manage your instance:

| Command | Description |
|---------|-------------|
| `cbup start` | Start the CBUP service |
| `cbup stop` | Stop the CBUP service |
| `cbup restart` | Restart the CBUP service |
| `cbup status` | Show service status, version, database size, uptime |
| `cbup logs [N]` | Tail service logs (default 50 lines) |
| `cbup update` | Pull latest code, rebuild, and restart (auto-backup) |
| `cbup backup` | Create a compressed database backup |
| `cbup restore <file>` | Restore database from a backup file |
| `cbup reset-db` | Delete all data and reinitialize the database |
| `cbup doctor` | Run diagnostics (service, disk, memory, HTTP health) |
| `cbup shell` | Open a shell in the app directory |
| `cbup uninstall` | Completely remove CBUP from the system |

---

## Docker Deployment

### Using the Installer

```bash
sudo ./install.sh --docker
```

### Manual Docker Build

```bash
# Clone and build
git clone https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

docker build -t cbup .

docker run -d \
  --name cyber-brief-up \
  --restart unless-stopped \
  -p 3000:3000 \
  -v cbup-data:/app/data \
  -e DATABASE_URL="file:/app/data/cbup.db" \
  cbup
```

### Docker Compose

```yaml
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

volumes:
  cbup-data:
```

---

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Database
DATABASE_URL="file:/var/lib/cbup/cbup.db"

# Application
NODE_ENV=production
PORT=3000

# Optional: Authentication
NEXTAUTH_SECRET="your-secret-key-here"
NEXTAUTH_URL="http://your-domain.com"
```

### Default Install Locations

| Path | Description |
|------|-------------|
| `/opt/cbup` | Application files |
| `/var/lib/cbup/cbup.db` | SQLite database |
| `/var/log/cbup/` | Application logs |
| `/var/backups/cbup/` | Database backups |
| `/etc/systemd/system/cbup.service` | Systemd service file |
| `/usr/local/bin/cbup` | Management CLI |

### Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 2 cores |
| RAM | 2 GB | 4 GB |
| Disk | 5 GB | 20 GB |
| OS | Ubuntu 20.04+ / Debian 11+ / CentOS 8+ | Same |

---

## Database

CBUP uses **SQLite** as its primary database, chosen for zero-configuration deployment, single-file portability, and excellent read performance for security data workloads.

See [docs/DATABASES.md](docs/DATABASES.md) for full database documentation including:

- Complete schema reference
- Entity Relationship Diagram
- Migration strategy
- Backup and restore procedures
- Performance optimization tips
- Multi-database roadmap (PostgreSQL, MySQL)

---

## Pricing Tiers

| Feature | Free | Starter | Pro | Enterprise |
|---------|------|---------|-----|------------|
| **Price** | $0/mo | $29/mo | $99/mo | Custom |
| **Users** | 1 | Up to 5 | Up to 25 | Unlimited |
| **Daily Alerts** | 3 headline | Full brief | Full + real-time | Custom feeds |
| **Briefings** | Weekly summary | Daily brief | Daily + on-demand | Custom format |
| **Workflow** | — | Basic tasks | Full Kanban | SIEM integration |
| **Monitoring** | — | Basic dashboard | Full analytics | Custom dashboards |
| **Compliance** | — | Basic reports | Full reports | SOC 2, HIPAA, PCI-DSS |
| **API Access** | — | — | Full REST API | Webhooks + API |
| **Deployment** | Cloud | Cloud | Cloud + on-prem | On-prem + air-gapped |
| **Support** | Community | Email | Priority (24h SLA) | Dedicated + SLA guarantees |
| **Data Retention** | 7 days | 90 days | 1 year | Unlimited |

---

## Project Structure

```
cyber-brief-unified-platform/
├── install.sh                    # 1-click installer script
├── README.md                     # This file
├── LICENSE                       # MIT License
├── docs/                         # Documentation
│   ├── DATABASES.md              # Database documentation
│   ├── HOWTO.md                  # How-to guides
│   ├── FAQ.md                    # Frequently asked questions
│   ├── CHANGELOG.md              # Version history
│   └── CONTRIBUTING.md           # Contributing guidelines
├── prisma/
│   └── schema.prisma             # Database schema
├── public/
│   ├── logo.svg                  # CBUP logo
│   └── robots.txt                # Search engine config
├── src/
│   ├── app/
│   │   ├── layout.tsx            # Root layout with metadata
│   │   ├── page.tsx              # Main SPA entry point
│   │   ├── globals.css           # Global styles + cyber theme
│   │   └── api/
│   │       ├── auth/signup/      # User registration endpoint
│   │       ├── alerts/           # Alert listing endpoint
│   │       ├── tasks/            # Task CRUD endpoints
│   │       ├── briefs/latest/    # Latest brief endpoint
│   │       └── dashboard/stats/  # Dashboard statistics
│   ├── components/
│   │   ├── landing/              # Landing page components
│   │   │   ├── hero.tsx
│   │   │   ├── features.tsx
│   │   │   ├── pricing.tsx
│   │   │   ├── sample-preview.tsx
│   │   │   └── testimonials.tsx
│   │   ├── auth/
│   │   │   └── signup-form.tsx   # Auth form (login/signup)
│   │   ├── dashboard/
│   │   │   └── dashboard-view.tsx
│   │   ├── alerts/
│   │   │   └── alerts-view.tsx   # Alert management
│   │   ├── briefs/
│   │   │   └── brief-view.tsx    # Daily brief display
│   │   ├── monitoring/
│   │   │   └── monitoring-view.tsx
│   │   ├── workflow/
│   │   │   └── workflow-view.tsx # Kanban board
│   │   ├── shared/
│   │   │   ├── navbar.tsx
│   │   │   └── footer.tsx
│   │   └── ui/                   # shadcn/ui components
│   ├── lib/
│   │   ├── store.ts              # Zustand global state
│   │   ├── db.ts                 # Prisma database client
│   │   ├── mock-data.ts          # Seed data for alerts/tasks/briefs
│   │   └── utils.ts              # Utility functions
│   └── hooks/                    # Custom React hooks
├── Caddyfile                     # Reverse proxy config
├── next.config.ts                # Next.js configuration
├── tailwind.config.ts            # Tailwind CSS configuration
├── components.json               # shadcn/ui configuration
├── tsconfig.json                 # TypeScript configuration
├── eslint.config.mjs             # ESLint configuration
├── package.json                  # Dependencies and scripts
└── bun.lock                      # Lock file
```

---

## API Reference

### Authentication

#### `POST /api/auth/signup`
Create a new user account.

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@company.com",
  "company": "Acme Corp",
  "password": "securepassword",
  "tier": "free"
}
```

**Response:** `201 Created`
```json
{
  "id": "clx...",
  "email": "john@company.com",
  "name": "John Doe",
  "company": "Acme Corp",
  "tier": "free",
  "createdAt": "2025-01-15T08:30:00.000Z"
}
```

### Alerts

#### `GET /api/alerts?severity=critical`
List security alerts with optional severity filter.

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `severity` | string | Filter by: `critical`, `high`, `medium`, `low` |

### Tasks

#### `GET /api/tasks`
List all workflow tasks.

#### `POST /api/tasks`
Create a new task.

**Request Body:**
```json
{
  "title": "Patch Apache Log4j",
  "description": "Update all production servers",
  "priority": "critical",
  "assignee": "Sarah Chen",
  "dueDate": "2025-01-16T23:59:00.000Z"
}
```

#### `PATCH /api/tasks/[id]`
Update a task (change status, priority, etc.).

### Briefs

#### `GET /api/briefs/latest`
Retrieve the latest published threat intelligence brief.

### Dashboard

#### `GET /api/dashboard/stats`
Retrieve aggregated statistics for the dashboard (active alerts, compliance score, threat level).

---

## Development

### Setup

```bash
# Install dependencies
bun install

# Generate Prisma client
bun run db:generate

# Push schema to database
bun run db:push

# Start dev server
bun run dev
```

### Code Quality

```bash
# Run linter
bun run lint

# Check TypeScript types
bunx tsc --noEmit
```

### Adding a New View

1. Create a component in `src/components/<section>/<view>.tsx`
2. Add the view type to the Zustand store in `src/lib/store.ts`
3. Import and add a conditional render block in `src/app/page.tsx`
4. Add a navigation entry in `src/components/shared/navbar.tsx`

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/DATABASES.md](docs/DATABASES.md) | Database schema, migrations, backup procedures |
| [docs/HOWTO.md](docs/HOWTO.md) | Step-by-step installation and configuration guides |
| [docs/FAQ.md](docs/FAQ.md) | Frequently asked questions and troubleshooting |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Version history, release notes, patching guide |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Code contribution guidelines and code change process |

---

## Versioning & Patching

CBUP follows [Semantic Versioning](https://semver.org/) (`MAJOR.MINOR.PATCH`).

- **MAJOR**: Breaking changes (API changes, schema migrations, UI overhauls)
- **MINOR**: New features (new views, API endpoints, integrations)
- **PATCH**: Bug fixes, security patches, documentation updates

See [docs/CHANGELOG.md](docs/CHANGELOG.md) for the full version history.

### Update Process

```bash
# Using the management CLI (recommended)
cbup update

# Manual update
cd /opt/cbup
git pull origin main
bun install
bun run db:push
bun run build
sudo systemctl restart cbup
```

---

## Security Considerations

- All API routes use input validation via Zod schemas
- The systemd service runs under a dedicated `cbup` user with no shell access
- Service hardening: `NoNewPrivileges=true`, `ProtectSystem=strict`, `PrivateTmp=true`
- SQLite database file permissions restricted to the `cbup` user only
- Environment variables containing secrets are not logged or exposed
- The platform is designed to run entirely within a private network

---

## Roadmap

- [ ] PostgreSQL and MySQL support for enterprise deployments
- [ ] NextAuth.js authentication with SSO/SAML/OIDC
- [ ] WebSocket real-time alert streaming
- [ ] PDF/Email briefing export
- [ ] Role-based access control (RBAC)
- [ ] SIEM integration (Splunk, Elastic, Sentinel)
- [ ] Vulnerability scanner integration (Nessus, OpenVAS)
- [ ] Custom threat feed aggregation
- [ ] Multi-language support (i18n)
- [ ] Mobile-responsive PWA

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Cyber Brief Unified Platform** — One platform. Every threat covered.

Built with Next.js, TypeScript, and Tailwind CSS.

</div>
