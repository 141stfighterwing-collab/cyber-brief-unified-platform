# Cyber Brief Unified Platform (CBUP)

<div align="center">

![CBUP Banner](https://img.shields.io/badge/CBUP-Cyber%20Brief%20Unified%20Platform-00C853?style=for-the-badge&logo=shield&logoColor=white)
![Version](https://img.shields.io/badge/version-2.4.0-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Next.js](https://img.shields.io/badge/Next.js-16.1-black?style=flat-square&logo=next.js)
![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6?style=flat-square&logo=typescript&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat-square&logo=docker&logoColor=white)

**One platform. Every threat covered.**

Unified cybersecurity awareness, real-time alerts, endpoint agent management, EDR scanning, workflow management, and low-level monitoring for organizations of any size. Self-hosted and on-prem ready.

[Get Started](#quick-start) · [Features](#features) · [Documentation](#docs/) · [Install Script](#installsh)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Quick Start](#quick-start)
- [Default Admin Credentials](#default-admin-credentials)
- [Important Warnings](#important-warnings)
- [1-Click Installation](#1-click-installation)
- [Docker Deployment](#docker-deployment)
- [Configuration](#configuration)
- [Database](#database)
- [Endpoint Agent System](#endpoint-agent-system)
- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Development](#development)
- [Documentation](#documentation)
- [Security Considerations](#security-considerations)
- [Roadmap](#roadmap)
- [License](#license)

---

## Overview

**Cyber Brief Unified Platform (CBUP)** is a comprehensive cybersecurity briefing and monitoring platform designed for organizations that need enterprise-grade security visibility without enterprise-grade complexity. Whether you're a small team or a large organization, CBUP gives your security team the tools to stay informed, respond to threats, manage endpoints, and maintain compliance — all from a single, self-hosted platform.

CBUP delivers curated threat intelligence briefings, real-time alerting for emerging vulnerabilities and active campaigns, cross-platform endpoint agents with EDR capabilities, C2 remote command execution, a workflow engine for tracking remediation tasks, and multi-tenant role-based access control. It is built to run on-premises or in any private cloud environment, giving you full control over your security data.

### Key Design Principles

- **Self-Hosted First**: Your security data stays in your infrastructure. No external dependencies.
- **Low Cost Impact**: Runs on a single server with minimal resources (1 CPU, 2 GB RAM minimum).
- **Zero Vendor Lock-In**: Open architecture with SQLite, standard REST APIs, and portable data.
- **Security-Conscious**: Built with defense-in-depth principles, least-privilege services, and hardened configurations.
- **Multi-Tenant Architecture**: Isolate data per organization with granular role-based access control.

---

## Features

### Multi-Tenant Cybersecurity Management
- Tenant isolation with unique authentication per organization
- Three-tier role-based access control: `user`, `admin`, `super_admin`
- Super-admin dashboard for cross-tenant visibility and management

### Endpoint Agent Management
- Cross-platform agents for Windows (PowerShell, EXE, System Tray) and Linux (Bash)
- Token-authenticated registration and per-tenant agent assignment
- Real-time telemetry: CPU, memory, disk I/O, network I/O, top processes, TCP connections
- Heartbeat monitoring and offline agent detection
- Remote C2 command execution (shell commands, EDR scan triggers, ping, restart)
- Deploy agents directly from the admin portal with one-liner install scripts

### EDR (Endpoint Detection & Response)
- 5 EDR scan types: Process analysis, service enumeration, port scanning, autorun/persistence detection, vulnerability assessment
- Full-scan orchestration combining all scan types into a single request
- Findings uploaded to the server with severity scoring and risk classification

### Real-Time Alert Monitoring
- 18+ pre-loaded realistic alerts covering CVEs, zero-days, phishing campaigns, ransomware, APTs, supply chain attacks, and data breaches
- Severity-based filtering: Critical, High, Medium, Low
- Category-based organization: Vulnerability, Malware, Phishing, Ransomware, APT, Supply Chain, Attack, Data Breach, Misconfiguration
- Searchable and expandable alert cards with full descriptions

### Security Briefs
- AI-curated cybersecurity briefings with threat intelligence summaries
- Severity-scored items with actionable recommendations
- Historical brief archive with full-text search

### Workflow & Task Management
- Kanban-style board with four columns: New, In Progress, Review, Completed
- Task creation with priority levels and assignee tracking
- Due date management and status transitions

### Security Reports Generation
- Automated report generation with PDF export
- Tenant-specific report history and detail views

### Monitoring & Analytics
- Interactive threat trend line charts (7-day rolling window)
- Alert distribution bar charts by category
- Severity breakdown donut charts
- System status indicators and health monitoring
- Real-time activity log timeline

---

## Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Next.js (App Router) | 16.1 |
| Language | TypeScript | 5.x |
| Runtime | Bun | 1.2+ |
| UI Library | shadcn/ui (New York) | Latest |
| CSS Framework | Tailwind CSS | 4.x |
| State Management | Zustand | 5.x |
| Database | SQLite via Prisma ORM | 6.x |
| Charts | Recharts | 2.x |
| Forms | React Hook Form + Zod | 7.x / 4.x |
| Animations | Framer Motion | 12.x |

---

## Quick Start

### Prerequisites

- **Bun** 1.0+ — [Install Bun](https://bun.sh/)
- **Git** — for cloning the repository

### Install & Run

```bash
# 1. Clone the repository
git clone https://github.com/141stfighterwing-collab/CBUP.git

# 2. Enter the project directory
cd CBUP

# 3. Install dependencies
bun install

# 4. Set up the SQLite database (pushes Prisma schema)
bun run db:push

# 5. Seed the database (creates default admin user + sample data)
bunx tsx prisma/seed.ts

# 6. Start the development server
bun run dev
```

The application will be available at **http://localhost:3001**.

> **Note:** The dev server runs on **port 3001** (not 3000) to avoid conflicts.

### Production Build

```bash
# Build for production
bun run build

# Start production server
bun run start
```

---

## Default Admin Credentials

After running the seed script, you can log in with the default super-admin account:

| Field | Value |
|-------|-------|
| **Email** | `admin@cbup.io` |
| **Password** | `CBUPadmin2024!` |

> **Important:** Change this password immediately after first login in a production environment.

---

## Important Warnings

> ### ⚠️ Do NOT Create a Nested Directory
>
> When cloning the repository, the URL produces a directory named `CBUP`. Make sure you do **not** accidentally create a nested `CBUP/CBUP/` directory. Clone and work directly from the cloned directory:
>
> ```bash
> # CORRECT — work from the cloned directory
> git clone https://github.com/141stfighterwing-collab/CBUP.git
> cd CBUP        # ← This is your project root
> bun install
>
> # WRONG — do not nest another CBUP inside
> cd CBUP
> git clone https://github.com/141stfighterwing-collab/CBUP.git  # ← creates CBUP/CBUP/
> ```
>
> If you accidentally created a nested directory, **delete the inner directory** and work from the outer directory.

> ### ⚠️ Do NOT Change the DATABASE_URL Path
>
> The `.env` file contains `DATABASE_URL=file:../db/custom.db`, which is a **relative path** from the Prisma schema location (`prisma/schema.prisma`). This path resolves correctly to the `db/custom.db` file in the project root.
>
> ```env
> # CORRECT — relative path from prisma/ directory
> DATABASE_URL=file:../db/custom.db
>
> # WRONG — do NOT change to an absolute path
> DATABASE_URL=file:/home/z/my-project/CBUP/db/custom.db
> ```
>
> Changing to an absolute path will break database connectivity.

---

## 1-Click Installation

The included `install.sh` script automates the entire installation process — from system prerequisites to a running production service.

### Quick Install (Bare Metal)

```bash
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
7. Seeds the database with default admin and sample data
8. Builds the Next.js production bundle
9. Creates a systemd service with security hardening
10. Configures firewall rules (UFW or firewalld)
11. Installs the `cbup` management CLI

### Management CLI

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

CBUP ships with production-ready Docker files for easy containerized deployment.

### Quick Start (Docker Compose)

```bash
git clone https://github.com/141stfighterwing-collab/CBUP.git
cd CBUP
docker compose up -d
```

### Custom Port

```bash
PORT=8080 docker compose up -d
```

### Manual Docker Build

```bash
docker build -t cbup:latest .
docker run -d \
  --name cbup \
  --restart unless-stopped \
  -p 3001:3001 \
  -v cbup-data:/app/data \
  -e DATABASE_URL="file:/app/data/custom.db" \
  cbup:latest
```

### Docker Management

```bash
# View logs
docker compose logs -f

# Check container health
docker compose ps

# Rebuild after code changes
docker compose up -d --build

# Stop (preserve data)
docker compose down

# Full reset (remove database too)
docker compose down -v
```

---

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Database — MUST remain a relative path from the prisma/ directory
DATABASE_URL="file:../db/custom.db"

# Application
NODE_ENV=development
PORT=3001

# Optional: Authentication
NEXTAUTH_SECRET="your-secret-key-here"
NEXTAUTH_URL="http://localhost:3001"
```

### Default Install Locations (Production)

| Path | Description |
|------|-------------|
| `/opt/cbup` | Application files |
| `/var/lib/cbup/` | SQLite database directory |
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

See [docs/DATABASES.md](docs/DATABASES.md) for full database documentation including schema reference, entity relationships, backup/restore procedures, and the multi-database roadmap.

---

## Endpoint Agent System

CBUP includes cross-platform endpoint monitoring agents that can be deployed to any Windows or Linux machine from the admin portal. Each tenant gets unique, token-authenticated download URLs.

### Supported Platforms

| Platform | Format | Installation |
|---------|--------|-------------|
| **Windows** | `.exe` (compiled) | One-liner or manual download |
| **Windows** | `.ps1` (PowerShell) | One-liner or manual download |
| **Windows** | `.ps1` (System Tray) | Optional GUI for status monitoring |
| **Linux** | `.sh` (Bash) | curl one-liner or manual download |
| **Docker** | Container | `docker run` or `docker-compose` |

### Agent Capabilities

- **System Discovery**: Hostname, domain, OS, serial number, BIOS, CPU, RAM, network, disks
- **Real-Time Telemetry**: CPU, memory, disk I/O, network I/O, top processes, TCP connections, uptime
- **5 EDR Scan Types**: Process analysis, service enumeration, port scanning, autorun/persistence detection, vulnerability assessment
- **Command & Control (C2)**: Remote shell execution, EDR scan triggers, ping, restart
- **Company Signatures**: Per-tenant SHA256 fingerprinting for EXE integrity verification
- **Gzip Compression**: For large telemetry payloads
- **Exponential Backoff Retry**: Resilient API communication

### Quick Install Examples

```powershell
# Windows PowerShell (one-liner)
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest -Uri 'https://YOUR-PORTAL/api/agents/install-script?platform=windows&token=TENANT_TOKEN' -OutFile 'CBUP-Agent.ps1'; .\CBUP-Agent.ps1 -ServerUrl 'https://YOUR-PORTAL' -Token TENANT_TOKEN -Install
```

```bash
# Linux (one-liner)
curl -fsSL 'https://YOUR-PORTAL/api/agents/install-script?platform=linux&token=TENANT_TOKEN' | sudo bash
```

```bash
# Docker
docker run -d --name cbup-agent --restart unless-stopped \
  -e CBUP_SERVER_URL='https://YOUR-PORTAL' \
  -e CBUP_AUTH_TOKEN='TENANT_TOKEN' \
  cbup/agent:latest
```

See [docs/HOWTO.md](docs/HOWTO.md#endpoint-agent-deployment) for the full deployment guide.

---

## Project Structure

```
CBUP/
├── src/
│   ├── app/                        # Next.js App Router pages and API routes
│   │   ├── layout.tsx              # Root layout with metadata
│   │   ├── page.tsx                # Main SPA entry point
│   │   ├── globals.css             # Global styles + cyber theme
│   │   └── api/                    # REST API endpoints
│   │       ├── auth/signup/        # User registration
│   │       ├── agents/             # Agent registration, telemetry, commands, EDR, downloads
│   │       ├── alerts/             # Alert listing and management
│   │       ├── tasks/              # Task CRUD
│   │       ├── briefs/             # Security briefs
│   │       ├── reports/            # Report generation and PDF export
│   │       ├── tenants/            # Tenant management
│   │       ├── dashboard/stats/    # Dashboard statistics
│   │       └── admin/              # Admin and super-admin endpoints
│   ├── components/
│   │   ├── landing/                # Landing page (hero, features, pricing, testimonials)
│   │   ├── auth/                   # Login and signup forms
│   │   ├── dashboard/              # Dashboard view
│   │   ├── agents/                 # Agent management, detail panel, C2 commands, deployment
│   │   ├── alerts/                 # Alert monitoring view
│   │   ├── briefs/                 # Security briefs view
│   │   ├── monitoring/             # Monitoring and analytics view
│   │   ├── workflow/               # Kanban task board
│   │   ├── reports/                # Report list and detail views
│   │   ├── admin/                  # Super-admin dashboard
│   │   ├── shared/                 # Shared navbar and footer
│   │   └── ui/                     # shadcn/ui base components
│   ├── lib/                        # Utilities, store, database client, auth checks
│   │   ├── store.ts                # Zustand global state management
│   │   ├── db.ts                   # Prisma database client
│   │   ├── auth-check.ts           # Authentication and authorization helpers
│   │   ├── security-utils.ts       # Security utility functions
│   │   ├── rate-limit.ts           # API rate limiting
│   │   ├── websocket.ts            # WebSocket support
│   │   ├── mock-data.ts            # Seed data for alerts/tasks/briefs
│   │   └── utils.ts                # General utility functions
│   └── hooks/                      # Custom React hooks
├── prisma/
│   ├── schema.prisma               # SQLite database schema (default)
│   ├── schema.postgresql.prisma    # PostgreSQL schema variant
│   ├── schema.mysql.prisma         # MySQL schema variant
│   └── seed.ts                     # Database seed script (admin + sample data)
├── db/                             # SQLite database files (auto-generated)
│   └── custom.db
├── agent/                          # Endpoint monitoring agents
│   ├── CBUP-Agent.ps1              # Windows PowerShell agent (entry point)
│   ├── CBUP-Agent-Tray.ps1         # Windows system tray application
│   ├── build-exe.ps1               # Windows EXE build script (ps2exe)
│   ├── cbup-agent-linux.sh         # Linux Bash agent
│   └── modules/                    # Modular PowerShell agent components (15 modules)
├── docs/                           # Documentation
│   ├── HOWTO.md                    # How-to guides
│   ├── FAQ.md                      # Frequently asked questions
│   ├── CHANGELOG.md                # Version history
│   ├── DATABASES.md                # Database documentation
│   ├── CONTRIBUTING.md             # Contributing guidelines
│   ├── PATCHING.md                 # Patch notes and upgrade instructions
│   └── TEST_MATRIX.md              # OS compatibility test matrix
├── Dockerfile                      # Production multi-stage Docker build
├── docker-compose.yml              # Production Docker Compose
├── Caddyfile                       # Reverse proxy config
├── install.sh                      # 1-click installer script
├── package.json                    # Dependencies and scripts
├── next.config.ts                  # Next.js configuration
├── tailwind.config.ts              # Tailwind CSS configuration
├── tsconfig.json                   # TypeScript configuration
├── components.json                 # shadcn/ui configuration
└── LICENSE                         # MIT License
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
  "password": "securepassword"
}
```

**Response:** `201 Created`

### Agents

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/agents/register` | POST | Register a new endpoint agent |
| `/api/agents/heartbeat` | POST | Agent heartbeat check-in |
| `/api/agents/[id]/telemetry` | POST | Submit agent telemetry data |
| `/api/agents/[id]/command` | POST | Issue C2 command to agent |
| `/api/agents/command-result` | POST | Agent returns command execution results |
| `/api/agents/edr-scan` | POST | Submit EDR scan results |
| `/api/agents/list` | GET | List agents for a tenant |
| `/api/agents/install-script` | GET | Get tenant-specific agent install script |
| `/api/agents/download-exe` | GET | Download Windows EXE agent build |

### Alerts

#### `GET /api/alerts?severity=critical`
List security alerts with optional severity filter.

| Parameter | Type | Description |
|-----------|------|-------------|
| `severity` | string | Filter by: `critical`, `high`, `medium`, `low` |

### Reports

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/reports` | GET | List reports |
| `/api/reports/generate` | POST | Generate a new security report |
| `/api/reports/[id]` | GET | Get report details |
| `/api/reports/[id]/pdf` | GET | Export report as PDF |

### Dashboard

#### `GET /api/dashboard/stats`
Retrieve aggregated statistics (active alerts, agent counts, compliance score, threat level).

---

## Development

### Setup

```bash
# Install dependencies
bun install

# Set up the database
bun run db:push

# Seed with default admin and sample data
bunx tsx prisma/seed.ts

# Start dev server (port 3001)
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
| [docs/PATCHING.md](docs/PATCHING.md) | Patch notes, security fixes, upgrade instructions |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Code contribution guidelines and code change process |

---

## Security Considerations

### Security Controls

- **Role-Based Access Control**: Three tiers — `user`, `admin`, `super_admin` — enforced across all API routes
- **Rate Limiting**: Sliding-window rate limiter on all critical endpoints (install-script, downloads, signup, commands)
- **Password Security**: Passwords hashed with scrypt (16-byte random salt, 64-byte key derivation)
- **Agent Token Encryption**: Windows DPAPI encryption for registry-stored credentials
- **C2 Command Sandboxing**: PowerShell AST-based allowlisting for remote script execution
- **File Collection Restrictions**: Path blocklist for sensitive files, 10 MB maximum transfer size
- **Cryptographic Signatures**: HMAC-SHA256 with server-side secret key for tenant identity verification
- **Input Validation**: Strict whitelists and regex validation on all user-supplied parameters
- **Security Headers**: CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy on all API responses

---

## Roadmap

- [ ] PostgreSQL and MySQL support for enterprise deployments
- [ ] WebSocket real-time alert streaming
- [ ] PDF/Email briefing export
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

Built with Next.js 16, TypeScript, and Tailwind CSS 4.

</div>
