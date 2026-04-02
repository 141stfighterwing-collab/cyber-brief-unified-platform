# Database Documentation

## Overview

Cyber Brief Unified Platform (CBUP) uses **SQLite** as its primary data store. SQLite was chosen for its zero-configuration deployment, single-file portability, excellent read performance, and complete isolation — all critical requirements for an on-premises cybersecurity platform.

## Database Engine

| Property | Value |
|----------|-------|
| Engine | SQLite 3.x |
| ORM | Prisma 6.x |
| Default Path | `/var/lib/cbup/cbup.db` |
| Connection | `DATABASE_URL="file:/var/lib/cbup/cbup.db"` |
| WAL Mode | Enabled (automatic via Prisma) |
| Max Connections | Single writer, multiple readers |
| Backup | File copy + gzip compression |

## Why SQLite?

CBUP is designed for on-premises and self-hosted deployment. SQLite provides several advantages over traditional client-server databases:

1. **Zero Configuration**: No separate database server to install, configure, or maintain. The database is a single file on disk.
2. **Low Resource Usage**: SQLite consumes minimal RAM and CPU, making it ideal for environments with limited resources (as low as 2GB RAM).
3. **Data Portability**: The entire database is a single file. Backups are as simple as copying the file. Migrations between servers require only transferring one file.
4. **Security Isolation**: No network-facing database ports. The database file lives entirely on the local filesystem with OS-level permission controls.
5. **Reliability**: SQLite is the most widely deployed database engine in the world, used by Android, iOS, macOS, Windows, and billions of devices.
6. **ACID Compliant**: Full transactional support with atomic commits, consistent isolation, and durable writes.

## Schema Reference

### Entity Relationship Diagram

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│     User     │     │    Alert     │     │    Brief     │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ id (PK)      │     │ id (PK)      │     │ id (PK)      │
│ email (UQ)   │     │ title        │     │ title        │
│ name         │     │ severity     │     │ volume       │
│ company      │     │ source       │     │ content      │
│ tier         │     │ description  │     │ publishedAt  │
│ password     │     │ category     │     └──────────────┘
│ createdAt    │     │ createdAt    │
│ updatedAt    │     └──────────────┘
└──────────────┘
                         
┌──────────────┐
│     Task     │
├──────────────┤
│ id (PK)      │
│ title        │
│ description  │
│ status       │
│ priority     │
│ assignee     │
│ dueDate      │
│ createdAt    │
│ updatedAt    │
└──────────────┘
```

### User Model

Stores user accounts and subscription tier information.

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  company   String?
  tier      String   @default("free")    // "free" | "starter" | "pro" | "enterprise"
  password  String?                       // Hashed password (bcrypt)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | String | PK, auto-generated (CUID) | Unique user identifier |
| `email` | String | Unique, required | User's email address (login) |
| `name` | String | Optional | Display name |
| `company` | String | Optional | Company/organization name |
| `tier` | String | Default: `"free"` | Subscription tier |
| `password` | String | Optional | Bcrypt-hashed password |
| `createdAt` | DateTime | Auto-generated | Account creation timestamp |
| `updatedAt` | DateTime | Auto-updated | Last modification timestamp |

**Tier Values:**
- `free` — Single user, limited features
- `starter` — Up to 5 users, daily briefs, basic workflow
- `pro` — Up to 25 users, real-time alerts, compliance, API
- `enterprise` — Unlimited users, on-prem, SIEM integration

### Alert Model

Stores cybersecurity alerts and threat intelligence items.

```prisma
model Alert {
  id          String   @id @default(cuid())
  title       String
  severity    String                       // "critical" | "high" | "medium" | "low"
  source      String
  description String
  category    String
  createdAt   DateTime @default(now())
}
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | String | PK, auto-generated (CUID) | Unique alert identifier |
| `title` | String | Required | Alert title (e.g., "CVE-2025-2177: Apache Log4j RCE") |
| `severity` | String | Required | Severity level |
| `source` | String | Required | Source of the alert (e.g., "NVD", "CISA", "FBI IC3") |
| `description` | String | Required | Full alert description with details |
| `category` | String | Required | Alert category |
| `createdAt` | DateTime | Auto-generated | Alert publication timestamp |

**Severity Levels:**
| Level | Color | Description | Response Time |
|-------|-------|-------------|---------------|
| `critical` | Red | Active exploitation, zero-days, mass compromise | Immediate (0-4 hours) |
| `high` | Orange | Significant vulnerability, active campaigns | Urgent (4-24 hours) |
| `medium` | Yellow | Potential risk, emerging threats | Standard (24-72 hours) |
| `low` | Green | Informational, best practices, advisories | Scheduled (1-2 weeks) |

**Category Values:**
| Category | Description |
|----------|-------------|
| `Vulnerability` | CVE entries, software flaws |
| `Malware` | New malware variants, botnets |
| `Phishing` | Phishing campaigns, social engineering |
| `Ransomware` | Ransomware operations, extortion |
| `APT` | Advanced persistent threat groups |
| `Supply Chain` | Compromised dependencies, vendors |
| `Attack` | Active attacks, DDoS, brute force |
| `Data Breach` | Data leaks, unauthorized access |
| `Misconfiguration` | Security misconfigurations |
| `Threat Intel` | Dark web intelligence, threat reports |
| `Configuration` | Best practices, deprecated protocols |

### Brief Model

Stores published daily cybersecurity briefings.

```prisma
model Brief {
  id          String   @id @default(cuid())
  title       String
  volume      Int
  content     String                       // JSON string with structured content
  publishedAt DateTime @default(now())
}
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | String | PK, auto-generated (CUID) | Unique brief identifier |
| `title` | String | Required | Brief title (e.g., "Cyber Brief Unified Platform") |
| `volume` | Int | Required | Volume/issue number (incrementing) |
| `content` | String | Required | JSON-serialized brief content |
| `publishedAt` | DateTime | Auto-generated | Publication timestamp |

**Content JSON Structure:**
```json
{
  "threatLevel": "ELEVATED",
  "threatScore": 78,
  "sections": [
    {
      "title": "Top Threats Today",
      "icon": "alert-triangle",
      "items": [
        {
          "title": "Apache Log4j RCE (CVE-2025-2177)",
          "summary": "Critical 10.0 CVSS vulnerability...",
          "severity": "critical"
        }
      ]
    }
  ]
}
```

### Task Model

Stores workflow and remediation tasks for security teams.

```prisma
model Task {
  id          String    @id @default(cuid())
  title       String
  description String?
  status      String    @default("new")       // "new" | "in_progress" | "review" | "completed"
  priority    String    @default("medium")    // "low" | "medium" | "high" | "critical"
  assignee    String?
  dueDate     DateTime?
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
}
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | String | PK, auto-generated (CUID) | Unique task identifier |
| `title` | String | Required | Task title (e.g., "Patch Apache Log4j to 2.24.2") |
| `description` | String | Optional | Detailed task description |
| `status` | String | Default: `"new"` | Current workflow status |
| `priority` | String | Default: `"medium"` | Task priority level |
| `assignee` | String | Optional | Assigned team member |
| `dueDate` | DateTime | Optional | Task deadline |
| `createdAt` | DateTime | Auto-generated | Task creation timestamp |
| `updatedAt` | DateTime | Auto-updated | Last modification timestamp |

**Status Workflow:**
```
┌──────┐    ┌────────────┐    ┌────────┐    ┌───────────┐
│ New  │───▶│ In Progress│───▶│ Review │───▶│ Completed │
└──────┘    └────────────┘    └────────┘    └───────────┘
```

## Database Operations

### Schema Changes

When modifying the Prisma schema:

```bash
# 1. Edit prisma/schema.prisma
# 2. Push changes to the database (non-destructive for additions)
bun run db:push

# Or for production with migration history:
bun run db:migrate dev --name describe-change
```

**Important Notes:**
- `db:push` is ideal for development and small deployments — it applies schema changes directly without creating migration files.
- `db:migrate` is recommended for production — it creates numbered migration files that can be version-controlled and rolled back.
- Never delete columns from the schema in production without a proper migration plan.
- Always backup the database before applying schema changes.

### Backups

#### Using the Management CLI (Recommended)

```bash
# Create a backup
cbup backup

# Output: /var/backups/cbup/cbup-backup-20250115-083000.db.gz
```

The backup system:
- Creates timestamped, gzip-compressed backups
- Automatically retains the last 30 backups (rotation)
- Stores backups in `/var/backups/cbup/`

#### Manual Backup

```bash
# Simple file copy
cp /var/lib/cbup/cbup.db /var/backups/cbup/manual-backup-$(date +%Y%m%d).db

# With compression
sqlite3 /var/lib/cbup/cbup.db ".backup /tmp/cbup-backup.db"
gzip /tmp/cbup-backup.db
mv /tmp/cbup-backup.db.gz /var/backups/cbup/
```

#### Automated Backup (Cron)

```bash
# Add to crontab (run daily at 2 AM)
echo "0 2 * * * /usr/local/bin/cbup backup" | crontab -
```

### Restore

```bash
# Restore from a specific backup
cbup restore /var/backups/cbup/cbup-backup-20250115-083000.db.gz

# Manual restore
gunzip -c /var/backups/cbup/cbup-backup-20250115.db.gz > /var/lib/cbup/cbup.db
sudo systemctl restart cbup
```

### Database Reset

```bash
# WARNING: This deletes ALL data
cbup reset-db

# Or manually:
rm /var/lib/cbup/cbup.db
cd /opt/cbup && DATABASE_URL="file:/var/lib/cbup/cbup.db" bun run db:push
```

## Performance

### Optimization Tips

1. **WAL Mode**: SQLite uses Write-Ahead Logging by default via Prisma, allowing concurrent reads during writes.
2. **Journal Mode**: The database uses `DELETE` journal mode by default. For better write performance, consider `WAL` mode:
   ```bash
   sqlite3 /var/lib/cbup/cbup.db "PRAGMA journal_mode=WAL;"
   ```
3. **Connection Pooling**: Prisma handles connection pooling automatically. The default pool size is sufficient for most deployments.
4. **Indexing**: Prisma automatically creates indexes for `@id` and `@unique` fields. Add `@index` annotations for frequently queried fields.

### Scaling Considerations

SQLite is suitable for deployments with:
- Up to 100 concurrent users
- Up to 10,000 alerts in the database
- Up to 1,000 tasks in the workflow
- Read-heavy workloads (most common for CBUP)

For deployments exceeding these limits, consider upgrading to PostgreSQL (see Future Support below).

## Multi-Database Roadmap

Future versions of CBUP will support additional database engines for enterprise deployments:

| Database | Status | Use Case |
|----------|--------|----------|
| SQLite | Current | Small to medium deployments, on-prem |
| PostgreSQL | Planned (v2.0) | Large deployments, high concurrency |
| MySQL | Planned (v2.0) | Organizations with existing MySQL infrastructure |

### Migration to PostgreSQL (Future)

When PostgreSQL support is added, migration will be as simple as:

```bash
# Set the new database URL
export DATABASE_URL="postgresql://cbup:password@localhost:5432/cbup"

# Push schema (Prisma handles the migration)
bun run db:push

# Migrate data from SQLite
bun run scripts/migrate-from-sqlite.ts
```

Prisma's database-agnostic ORM means no application code changes will be required.
