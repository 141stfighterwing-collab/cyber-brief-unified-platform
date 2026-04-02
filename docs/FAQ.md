# Frequently Asked Questions

## General

### What is Cyber Brief Unified Platform (CBUP)?

CBUP is a self-hosted cybersecurity awareness and monitoring platform designed for companies of any size. It provides daily threat intelligence briefings, real-time alert management, a workflow engine for security task tracking, and monitoring dashboards — all from a single, on-premises deployable application. Think of it as your team's daily security newspaper combined with an incident response workspace.

### Who is CBUP for?

CBUP is designed for any organization that needs cybersecurity awareness but may not have the budget for enterprise-grade tools like Splunk, CrowdStrike, or Palo Alto. This includes small-to-medium businesses, startups, MSPs (Managed Security Providers), internal security teams at larger companies, government agencies, educational institutions, and non-profit organizations. The Free tier is even suitable for individual security researchers and consultants.

### Is CBUP really free?

Yes, the Free tier has no cost and no time limit. It includes daily headline alerts (up to 3 per day), weekly summary briefs, a basic threat indicator feed, and community support. You can use it indefinitely. Paid tiers unlock additional users, full daily briefs, real-time alerts, workflow management, compliance reporting, API access, and priority support.

### What does "on-prem ready" mean?

CBUP is designed to run entirely within your own infrastructure. Your data never leaves your servers. There are no external API calls to third-party services (except optional integrations you configure). The application, database, and all data files reside on hardware you control. This is critical for organizations with data sovereignty requirements, compliance mandates (HIPAA, ITAR, FedRAMP), or security policies that prohibit cloud-hosted SaaS tools.

---

## Installation & Deployment

### What are the system requirements?

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 2 GB | 4+ GB |
| Disk | 5 GB | 20+ GB |
| OS | Ubuntu 20.04, Debian 11, CentOS 8, RHEL 8 | Same or newer |
| Architecture | x86_64 or ARM64 | Same |

### Can I install CBUP without root access?

No, the 1-click installer requires root access (sudo) because it needs to create system users, install packages, set up systemd services, and configure firewall rules. However, you can run CBUP in development mode without root:

```bash
git clone <repo-url>
cd cyber-brief-unified-platform
bun install
bun run db:push
bun run dev
```

This runs on port 3000 without any system-level changes.

### Does CBUP work behind a corporate proxy?

Yes. If your server is behind a corporate proxy, set the `HTTP_PROXY` and `HTTPS_PROXY` environment variables before running the installer:

```bash
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
sudo -E ./install.sh
```

For runtime, add the proxy variables to `/opt/cbup/.env`.

### Can I run CBUP in a Docker container?

Yes. CBUP includes full Docker support with both a `Dockerfile` and `docker-compose.yml`:

```bash
# Quick Docker install
sudo ./install.sh --docker

# Or manual Docker build
docker build -t cbup .
docker run -d -p 3000:3000 -v cbup-data:/app/data cbup
```

### Can I run CBUP on a Raspberry Pi?

Yes, CBUP supports ARM64 architecture (used by Raspberry Pi 4/5). Use the bare metal installation method. Note that build times will be longer on ARM devices.

### How do I install CBUP on air-gapped networks?

For air-gapped environments (no internet access):

1. On a machine with internet access, clone the repo and run `bun install` to download all dependencies.
2. Transfer the entire project directory to the air-gapped server via USB or secure media.
3. On the air-gapped server, run the manual installation steps from the HOWTO guide.
4. No external connections are needed at runtime — CBUP operates entirely offline after installation.

---

## Database & Data

### What database does CBUP use?

CBUP uses SQLite, a serverless, zero-configuration database engine. The entire database is stored as a single file (`/var/lib/cbup/cbup.db`). This was chosen for its reliability, portability, and zero-dependency deployment model. See [docs/DATABASES.md](DATABASES.md) for complete database documentation.

### Will CBUP support PostgreSQL or MySQL?

Yes. PostgreSQL and MySQL support are planned for v2.0. Prisma ORM (which CBUP uses) makes switching databases straightforward — only the connection string changes, no application code modifications are needed. The timeline depends on community demand and enterprise customer requirements.

### How do I back up my data?

```bash
# One command — creates a compressed backup with timestamp
cbup backup

# Set up automatic daily backups at 2 AM
echo "0 2 * * * /usr/local/bin/cbup backup" | sudo crontab -
```

Backups are stored in `/var/backups/cbup/` and automatically rotated (last 30 kept).

### Can I export my data?

Yes. Since CBUP uses SQLite, you can export data using standard SQLite tools:

```bash
# Export all data to SQL
sqlite3 /var/lib/cbup/cbup.db .dump > cbup-export.sql

# Export to CSV
sqlite3 /var/lib/cbup/cbup.db -header -csv "SELECT * FROM Alert;" > alerts.csv
sqlite3 /var/lib/cbup/cbup.db -header -csv "SELECT * FROM Task;" > tasks.csv
sqlite3 /var/lib/cbup/cbup.db -header -csv "SELECT * FROM User;" > users.csv
```

### How much disk space does CBUP use?

| Component | Fresh Install | After 1 Year (Est.) |
|-----------|---------------|---------------------|
| Application | ~200 MB | ~200 MB |
| Database | ~1 MB | ~50-200 MB |
| Logs | ~5 MB/week | ~250 MB |
| Backups (30 rotating) | ~1 MB each | ~100 MB each |

With 10 GB of disk space, CBUP can comfortably run for years without cleanup.

### Is the database encrypted?

SQLite supports encryption via the SQLCipher extension, but CBUP currently does not enable it by default. For encrypted databases, you can:
1. Use full-disk encryption (LUKS on Linux) — recommended for on-prem deployments.
2. Wait for v1.1, which will add optional SQLCipher support.

---

## Usage & Features

### How often are alerts updated?

Alerts are currently populated from mock data for demonstration purposes. In a production deployment (coming in v1.0), alerts will be:
- **Free tier**: Updated once daily at 6:00 AM local time.
- **Starter tier**: Updated every 4 hours.
- **Pro tier**: Real-time streaming via WebSocket.
- **Enterprise tier**: Real-time + custom threat feeds with configurable intervals.

### Can I add custom alerts?

In the current version, alerts are managed via the API and database. You can insert custom alerts using the API:

```bash
curl -X POST http://localhost:3000/api/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Custom Alert: Suspicious Login Detected",
    "severity": "high",
    "source": "Internal SIEM",
    "description": "Multiple failed login attempts detected for user admin@company.com from IP 10.0.0.55",
    "category": "Attack"
  }'
```

### How does the workflow/Kanban board work?

The workflow board has four columns representing task lifecycle stages:

1. **New** — Tasks that have been identified but not yet assigned or started.
2. **In Progress** — Tasks currently being worked on by a team member.
3. **Review** — Tasks that require verification or peer review before closure.
4. **Completed** — Tasks that have been fully resolved.

Click any task card to move it to the next stage. You can also create new tasks with a title, description, priority level, assignee, and due date.

### Can multiple users use CBUP simultaneously?

Yes. Multiple users can access the platform simultaneously through their browsers. Each user has their own session. The Free tier supports 1 user, Starter supports up to 5, Pro supports up to 25, and Enterprise supports unlimited concurrent users.

### Does CBUP send email notifications?

Not in the current version. Email notifications for daily briefs, alert escalations, and task assignments are planned for v1.1. The Enterprise tier will also support webhook integrations for Slack, Microsoft Teams, and PagerDuty.

---

## Security & Compliance

### Is CBUP itself secure?

CBUP follows security best practices:
- The application runs under a dedicated, non-root system user (`cbup`) with no shell access.
- Systemd hardening: `NoNewPrivileges=true`, `ProtectSystem=strict`, `PrivateTmp=true`.
- Database file permissions are restricted to the `cbup` user only.
- No external API calls are made from the application.
- All API routes use input validation.
- Source code is open for security audit.

### Does CBUP meet compliance requirements?

CBUP is a tool that supports compliance efforts, but compliance depends on how you configure and use it within your organization:

- **SOC 2**: CBUP's audit logging and access controls support SOC 2 Type II requirements.
- **HIPAA**: On-prem deployment with encryption meets HIPAA technical safeguards.
- **PCI-DSS**: Alert monitoring and vulnerability tracking support PCI-DSS requirements.
- **NIST CSF**: The platform maps directly to the Detect and Respond functions of the NIST Cybersecurity Framework.

### Can I integrate CBUP with my SIEM?

SIEM integration (Splunk, Elastic SIEM, Microsoft Sentinel) is planned for the Enterprise tier in v2.0. It will include:
- Syslog forwarding for alerts and events
- REST API for querying briefs and tasks
- Webhook notifications for real-time alert streaming
- A Python/Node.js SDK for custom integrations

---

## Licensing & Pricing

### What is the license?

CBUP is released under the **MIT License**. You are free to use, modify, distribute, and use it for commercial purposes. See the [LICENSE](../LICENSE) file for the full text.

### Why are there paid tiers if the code is open source?

CBUP is open-source software. The paid tiers represent **support and hosting services**, not restrictions on the software itself. Anyone can self-host the full-featured application for free. Paid tiers provide:
- **Priority support** with guaranteed response times
- **Managed hosting** if you don't want to self-host
- **Custom integrations** and consulting
- **Compliance assistance** and reporting templates
- **SLA guarantees** for enterprise deployments

### Can I use CBUP commercially?

Yes. The MIT License permits commercial use without any restrictions. You can deploy CBUP within your company, use it to provide security services to clients, or build commercial products on top of it.

---

## Troubleshooting

### The page won't load after installation

1. Check if the service is running: `cbup status`
2. Check if the port is listening: `ss -tlnp | grep 3000`
3. Check logs for errors: `cbup logs 50`
4. Verify the build completed successfully: `ls -la /opt/cbup/.next/standalone/`
5. Try restarting: `cbup restart`

### I forgot my password

Currently, passwords can be reset via the database. A proper password reset flow with email verification is planned for v1.0:

```bash
sqlite3 /var/lib/cbup/cbup.db "UPDATE User SET password = NULL WHERE email = 'your@email.com';"
```

### The database seems corrupted

1. Check integrity: `sqlite3 /var/lib/cbup/cbup.db "PRAGMA integrity_check;"`
2. If corrupted, restore from backup: `cbup restore`
3. If no backup exists, reset the database: `cbup reset-db` (WARNING: deletes all data)

### How do I completely remove CBUP?

```bash
# Using the CLI (recommended)
cbup uninstall

# This removes: application files, logs, service, CLI
# The database at /var/lib/cbup/ is preserved — remove manually if needed:
sudo rm -rf /var/lib/cbup
```

### The 1-click installer fails on my OS

The installer supports Ubuntu 20.04+, Debian 11+, CentOS 8+, RHEL 8+, Fedora, and Amazon Linux. For other distributions, use the manual installation steps from the [HOWTO guide](HOWTO.md). If you encounter a bug, please open an issue on GitHub with your OS details and the error output.

---

## Getting Help

- **Documentation**: [docs/](./) — Full documentation library
- **GitHub Issues**: [Report bugs and request features](https://github.com/141stfighterwing-collab/cyber-brief-unified-platform/issues)
- **CLI Diagnostics**: Run `cbup doctor` to check system health
- **Community Support**: Available for Free tier users via GitHub Discussions
- **Email Support**: Available for Starter tier and above
- **Priority Support**: Available for Pro tier with 24-hour SLA
- **Dedicated Support**: Available for Enterprise tier with named account manager
