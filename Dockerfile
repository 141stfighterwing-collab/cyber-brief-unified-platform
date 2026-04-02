# ─── Cyber Brief Unified Platform (CBUP) ───
# Multi-stage Docker build for production deployment
#
# Usage:
#   docker compose up -d              # Production (recommended)
#   docker compose -f docker-compose.dev.yml up  # Development
#
# Build:
#   docker compose build              # Build from this Dockerfile
#   docker build -t cbup:latest .     # Direct build

# ══════════════════════════════════════════════════════
# Stage 1: Dependencies
# ══════════════════════════════════════════════════════
FROM node:20-slim AS deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl unzip ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Bun
RUN npm install -g bun@1.2.2 || npm install -g bun

WORKDIR /app

# Copy lock files for dependency caching
COPY package.json bun.lock ./

# Install dependencies (use frozen if available, fallback to fresh install)
RUN bun install --frozen-lockfile 2>/dev/null || bun install

# ══════════════════════════════════════════════════════
# Stage 2: Build
# ══════════════════════════════════════════════════════
FROM deps AS builder

WORKDIR /app

# Copy all source files
COPY . .

# Generate Prisma client
RUN bunx prisma generate

# Set DATABASE_URL for build time (Prisma needs it)
ENV DATABASE_URL="file:/app/data/cbup.db"

# Build Next.js standalone output
# The build script copies .next/static and public into standalone dir
RUN bun run build

# ══════════════════════════════════════════════════════
# Stage 3: Production Runner
# ══════════════════════════════════════════════════════
FROM node:20-slim AS runner

LABEL maintainer="CBUP Team"
LABEL description="Cyber Brief Unified Platform - Cybersecurity Awareness & Monitoring"
LABEL version="0.2.0"

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssl curl ca-certificates tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Run as non-root user for security
RUN groupadd --system --gid 1001 cbup && \
    useradd --system --uid 1001 --gid cbup --shell /usr/sbin/nologin cbup

# Set environment
ENV NODE_ENV=production
ENV PORT=3000
ENV DATABASE_URL="file:/app/data/cbup.db"
ENV HOSTNAME="0.0.0.0"

# Copy standalone output from builder
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# Copy Prisma schema for runtime migrations if needed
COPY --from=builder /app/prisma ./prisma

# Copy node_modules for Prisma runtime
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

# Create data directory and set ownership
RUN mkdir -p /app/data /app/logs && \
    chown -R cbup:cbup /app

USER cbup

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --start-interval=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Use tini as init system for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["node", "server.js"]
