/**
 * CBUP Database Seed Script
 *
 * Creates default data for development:
 * - Super admin user (admin@cbup.local / admin123)
 * - Default tenant organization ("Default Organization")
 * - Associates admin user with the default tenant as owner
 *
 * Run: npx prisma db seed
 *   or: npx tsx prisma/seed.ts
 */

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 CBUP Seed: Starting...')

  // -------------------------------------------------------------------------
  // 1. Create default super_admin user
  // -------------------------------------------------------------------------
  console.log('  → Creating super_admin user...')

  // In production, passwords should be hashed with bcrypt.
  // For dev seed, we store plain text (admin123).
  const adminEmail = 'admin@cbup.local'
  const adminPassword = 'admin123'

  let adminUser = await prisma.user.findUnique({
    where: { email: adminEmail },
  })

  if (!adminUser) {
    adminUser = await prisma.user.create({
      data: {
        email: adminEmail,
        name: 'CBUP Administrator',
        company: 'Cyber Brief Unified Platform',
        role: 'super_admin',
        password: adminPassword,
        tier: 'enterprise',
        settings: JSON.stringify({
          theme: 'dark',
          notifications: true,
          language: 'en',
        }),
      },
    })
    console.log(`    ✓ Created admin user: ${adminEmail} (id: ${adminUser.id})`)
  } else {
    console.log(`    ↻ Admin user already exists: ${adminEmail} (id: ${adminUser.id})`)
  }

  // -------------------------------------------------------------------------
  // 2. Create default tenant
  // -------------------------------------------------------------------------
  console.log('  → Creating default tenant...')

  const defaultSlug = 'default'
  let defaultTenant = await prisma.tenant.findUnique({
    where: { slug: defaultSlug },
  })

  if (!defaultTenant) {
    defaultTenant = await prisma.tenant.create({
      data: {
        name: 'Default Organization',
        slug: defaultSlug,
        description: 'Default organization for the CBUP platform. All new agents and resources are assigned here by default.',
        plan: 'enterprise',
        maxAgents: 100,
        settings: JSON.stringify({
          alertThreshold: 'medium',
          autoResolveDays: 30,
          scanSchedule: 'daily',
        }),
        active: true,
      },
    })
    console.log(`    ✓ Created tenant: "${defaultTenant.name}" (id: ${defaultTenant.id})`)
  } else {
    console.log(`    ↻ Default tenant already exists: "${defaultTenant.name}" (id: ${defaultTenant.id})`)
  }

  // -------------------------------------------------------------------------
  // 3. Associate admin user with default tenant as owner
  // -------------------------------------------------------------------------
  console.log('  → Associating admin with default tenant...')

  let tenantUser = await prisma.tenantUser.findUnique({
    where: {
      tenantId_userId: {
        tenantId: defaultTenant.id,
        userId: adminUser.id,
      },
    },
  })

  if (!tenantUser) {
    tenantUser = await prisma.tenantUser.create({
      data: {
        tenantId: defaultTenant.id,
        userId: adminUser.id,
        role: 'owner',
      },
    })
    console.log(`    ✓ Created tenant membership: ${adminUser.email} → ${defaultTenant.name} (role: owner)`)
  } else {
    console.log(`    ↻ Membership already exists: ${adminUser.email} → ${defaultTenant.name} (role: ${tenantUser.role})`)
  }

  // -------------------------------------------------------------------------
  // 4. Create sample alerts for the default tenant
  // -------------------------------------------------------------------------
  console.log('  → Creating sample alerts...')

  const sampleAlerts = [
    {
      title: 'CVE-2024-3094: XZ Utils Backdoor Detection',
      severity: 'critical',
      source: 'CVE Feed',
      description: 'A sophisticated supply chain backdoor was identified in xz-utils versions 5.6.0 and 5.6.1. The malicious code could allow unauthorized SSH access to affected systems.',
      category: 'vulnerability',
      tenantId: defaultTenant.id,
    },
    {
      title: 'Suspicious PowerShell Execution Detected',
      severity: 'high',
      source: 'EDR',
      description: 'Encoded PowerShell command execution detected from an unusual process tree. Potential credential harvesting or lateral movement activity.',
      category: 'malware',
      tenantId: defaultTenant.id,
    },
    {
      title: 'Phishing Campaign Targeting Finance Department',
      severity: 'high',
      source: 'Email Gateway',
      description: 'A coordinated phishing campaign targeting finance staff has been detected. 12 emails were quarantined containing malicious Office macros.',
      category: 'phishing',
      tenantId: defaultTenant.id,
    },
    {
      title: 'Unusual RDP Connection from External IP',
      severity: 'medium',
      source: 'Firewall',
      description: 'Multiple RDP connection attempts detected from an IP block known for brute-force activity. Connections were blocked by the firewall.',
      category: 'network',
      tenantId: defaultTenant.id,
    },
    {
      title: 'SSL Certificate Expiring in 7 Days',
      severity: 'low',
      source: 'Certificate Monitor',
      description: 'The SSL certificate for api.internal.cbup.local will expire in 7 days. Renewal is required to maintain secure communications.',
      category: 'compliance',
      tenantId: defaultTenant.id,
    },
  ]

  for (const alert of sampleAlerts) {
    const exists = await prisma.alert.findFirst({
      where: { title: alert.title, tenantId: alert.tenantId },
    })
    if (!exists) {
      await prisma.alert.create({ data: alert })
      console.log(`    ✓ Created alert: "${alert.title}"`)
    } else {
      console.log(`    ↻ Alert already exists: "${alert.title}"`)
    }
  }

  // -------------------------------------------------------------------------
  // Done
  // -------------------------------------------------------------------------
  console.log('')
  console.log('✅ CBUP Seed: Complete!')
  console.log('')
  console.log('  Credentials:')
  console.log(`    Email:    ${adminEmail}`)
  console.log(`    Password: ${adminPassword}`)
  console.log('')
  console.log(`  Tenant: ${defaultTenant.name} (${defaultTenant.slug})`)
  console.log('')
}

main()
  .catch((error) => {
    console.error('❌ Seed failed:', error)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
