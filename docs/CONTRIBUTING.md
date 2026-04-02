# Contributing to Cyber Brief Unified Platform

Thank you for your interest in contributing to CBUP! This guide covers everything you need to know about contributing code, reporting bugs, requesting features, and understanding the development workflow.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Project Architecture](#project-architecture)
- [Making Changes](#making-changes)
- [Code Standards](#code-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Database Changes](#database-changes)
- [Adding New Features](#adding-new-features)
- [Testing](#testing)
- [Reporting Bugs](#reporting-bugs)
- [Requesting Features](#requesting-features)
- [Release Process](#release-process)

---

## Code of Conduct

- Be respectful and constructive in all interactions
- Welcome newcomers and help them get started
- Focus on what is best for the community and the project
- Accept that not all contributions will be merged
- Provide clear, actionable feedback during code reviews

---

## Getting Started

### Fork the Repository

```bash
# 1. Fork the repo on GitHub
# 2. Clone your fork
git clone https://github.com/YOUR-USERNAME/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

# 3. Add the upstream remote
git remote add upstream https://github.com/141stfighterwing-collab/cyber-brief-unified-platform.git
```

### Branch Naming Convention

Use descriptive branch names that indicate the type of change:

```
feat/description     # New feature
fix/description      # Bug fix
docs/description     # Documentation changes
refactor/description # Code refactoring
perf/description     # Performance improvements
style/description    # Code style changes (formatting)
test/description     # Adding or updating tests
chore/description    # Maintenance tasks
```

Examples:
- `feat/add-email-notifications`
- `fix/fix-alert-filter-severity`
- `docs/update-api-documentation`
- `refactor/simplify-workflow-state`

---

## Development Environment Setup

### Prerequisites

- **Bun** 1.0+ — [Install Bun](https://bun.sh/)
- **Git** — Latest stable
- **VS Code** (recommended) with the following extensions:
  - ESLint
  - Tailwind CSS IntelliSense
  - Prisma
  - TypeScript

### Setup Steps

```bash
# 1. Clone the repository
git clone https://github.com/YOUR-USERNAME/cyber-brief-unified-platform.git
cd cyber-brief-unified-platform

# 2. Install dependencies
bun install

# 3. Set up the database
bun run db:push

# 4. Generate Prisma client
bun run db:generate

# 5. Start the development server
bun run dev
```

The application will be available at `http://localhost:3000`.

### Environment Variables

Create a `.env` file in the project root for development:

```env
DATABASE_URL="file:./db/custom.db"
NODE_ENV=development
PORT=3000
```

---

## Project Architecture

### Single-Page Application

CBUP is built as a **single-page application (SPA)** using client-side state-driven navigation. All views are rendered within a single `/` route:

```
src/app/page.tsx          ← Main entry point, renders views based on Zustand state
src/lib/store.ts          ← Zustand store manages currentView and user state
```

### View System

The app uses a Zustand store with a `currentView` field to determine which view to render:

```typescript
// In src/lib/store.ts
interface AppState {
  currentView: 'landing' | 'auth' | 'dashboard' | 'alerts' | 'briefs' | 'monitoring' | 'workflow'
  setView: (view: AppState['currentView']) => void
}
```

### Component Organization

```
src/components/
├── landing/          # Landing page sections (hero, features, pricing, etc.)
├── auth/             # Authentication forms
├── dashboard/        # Dashboard view and sub-components
├── alerts/           # Alert management view
├── briefs/           # Daily brief display
├── monitoring/       # Monitoring dashboards with charts
├── workflow/         # Kanban board
├── shared/           # Navbar, footer, and other shared components
└── ui/               # shadcn/ui base components (do not modify)
```

### Data Flow

```
User Action → Component → Zustand Store → View Re-render
              ↓
         API Route (server)
              ↓
         Prisma ORM → SQLite Database
```

---

## Making Changes

### Workflow

1. **Create a branch** from `main`
2. **Make your changes** following the code standards
3. **Test your changes** locally
4. **Run the linter** (`bun run lint`)
5. **Commit with a descriptive message**
6. **Push to your fork**
7. **Open a Pull Request** against `main`

### Keeping Your Branch Updated

```bash
# Sync with upstream
git fetch upstream
git rebase upstream/main

# Resolve any conflicts
git add .
git rebase --continue
```

---

## Code Standards

### TypeScript

- Use TypeScript strict mode for all new files
- Prefer `interface` over `type` for object shapes
- Use explicit return types for functions
- Avoid `any` — use `unknown` and type narrowing instead

```typescript
// Good
interface AlertFilter {
  severity: 'critical' | 'high' | 'medium' | 'low'
  category?: string
  dateFrom?: Date
}

function filterAlerts(alerts: Alert[], filter: AlertFilter): Alert[] {
  return alerts.filter(alert => alert.severity === filter.severity)
}

// Bad
function filterAlerts(alerts: any, filter: any): any {
  return alerts.filter(a => a.severity === filter.severity)
}
```

### React Components

- Use functional components with hooks
- Keep components small and focused (single responsibility)
- Extract reusable logic into custom hooks
- Use `useCallback` and `useMemo` for performance-sensitive operations
- Always add `'use client'` directive for client components

```typescript
'use client'

import { useState, useCallback } from 'react'

interface AlertCardProps {
  title: string
  severity: 'critical' | 'high' | 'medium' | 'low'
  onAction: (id: string) => void
}

export function AlertCard({ title, severity, onAction }: AlertCardProps) {
  const [expanded, setExpanded] = useState(false)
  const handleAction = useCallback(() => {
    onAction(title)
  }, [onAction, title])

  return (
    <div className="p-4 rounded-lg border">
      <h3 className="font-semibold">{title}</h3>
      <span className={`text-xs ${severity === 'critical' ? 'text-red-500' : ''}`}>
        {severity}
      </span>
      <button onClick={handleAction}>Take Action</button>
    </div>
  )
}
```

### Styling

- Use Tailwind CSS utility classes exclusively
- Do NOT use inline styles (except for dynamic values)
- Follow the mobile-first responsive design approach
- Use the shadcn/ui component library for UI elements
- Maintain consistent spacing (multiples of 4: p-4, gap-4, m-6)
- Avoid indigo or blue colors unless explicitly requested — use the emerald/green cybersecurity theme

### File Naming

- Components: `kebab-case.tsx` (e.g., `alert-card.tsx`, `workflow-view.tsx`)
- Utilities: `kebab-case.ts` (e.g., `mock-data.ts`, `utils.ts`)
- API routes: `route.ts` in lowercase directories (e.g., `api/alerts/route.ts`)
- CSS: `kebab-case.css` (e.g., `globals.css`)

---

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Code style (formatting, semicolons) |
| `refactor` | Code refactoring (no feature/fix) |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Maintenance, build, dependencies |
| `ci` | CI/CD configuration changes |

### Examples

```
feat(alerts): add severity filter dropdown

Fixes #42

feat(workflow): implement drag-and-drop task reordering

Users can now drag tasks between Kanban columns.
Uses @dnd-kit/core for accessibility support.

fix(auth): resolve login redirect loop on expired sessions

docs(api): update alert endpoint response schema

refactor(store): simplify Zustand state management
```

---

## Pull Request Process

### Before Submitting

1. Ensure all tests pass: `bun run lint`
2. Verify the dev server starts: `bun run dev`
3. Check for TypeScript errors: `bunx tsc --noEmit`
4. Test your changes manually in the browser
5. Update documentation if needed

### PR Template

When opening a PR, include:

```markdown
## Description
Brief description of what this PR does and why.

## Type of Change
- [ ] Feature (new functionality)
- [ ] Bug fix (non-breaking fix)
- [ ] Breaking change (fix or feature that breaks existing functionality)
- [ ] Documentation
- [ ] Refactoring

## Testing
How was this change tested?

## Screenshots (if applicable)
Before / After screenshots.

## Checklist
- [ ] Code compiles without errors
- [ ] Linter passes (`bun run lint`)
- [ ] No TypeScript errors
- [ ] Documentation updated (if needed)
- [ ] No new dependencies added without justification
```

### Review Process

1. At least one maintainer review is required
2. Address all review comments
3. Squash commits if requested
4. Maintainer will merge when approved

---

## Database Changes

### Schema Modifications

When you need to modify the database schema:

1. **Edit** `prisma/schema.prisma`
2. **Push** the schema for development: `bun run db:push`
3. **Test** that the application works with the new schema
4. **Document** the change in your PR description
5. **Include** a migration note for production deployments

### Adding a New Model

```prisma
// prisma/schema.prisma
model NewModel {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

### Adding a New Field to an Existing Model

```prisma
// Adding an optional field (safe, non-breaking)
model User {
  // ... existing fields ...
  department String?   // Optional, safe to add
}

// Adding a required field with default (safe, non-breaking)
model User {
  // ... existing fields ...
  role      String   @default("viewer")  // Has default, safe to add
}
```

**Important**: Never add a required field without a default value to an existing model — this is a breaking change that requires a data migration.

### Creating API Routes for New Models

Follow the existing patterns in `src/app/api/`:

```typescript
// src/app/api/new-model/route.ts
import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

export async function GET() {
  const items = await db.newModel.findMany({
    orderBy: { createdAt: 'desc' },
  })
  return NextResponse.json(items)
}

export async function POST(request: Request) {
  const body = await request.json()
  const item = await db.newModel.create({
    data: body,
  })
  return NextResponse.json(item, { status: 201 })
}
```

---

## Adding New Features

### Adding a New View

1. **Update the store** in `src/lib/store.ts`:
   ```typescript
   // Add the new view to the union type
   currentView: 'landing' | 'auth' | 'dashboard' | 'alerts' | 'briefs' | 'monitoring' | 'workflow' | 'newview'
   ```

2. **Create the component** in `src/components/<section>/new-view.tsx`:
   ```typescript
   'use client'
   
   export function NewView() {
     return <div>Your new view content</div>
   }
   ```

3. **Add navigation** in `src/components/shared/navbar.tsx`:
   ```typescript
   const navItems = [
     // ... existing items ...
     { id: 'newview' as const, label: 'New View' },
   ]
   ```

4. **Add the render block** in `src/app/page.tsx`:
   ```typescript
   {currentView === 'newview' && (
     <div className="container mx-auto px-4 lg:px-6 py-6">
       <NewView />
     </div>
   )}
   ```

### Adding API Endpoints

Create route handlers in `src/app/api/`:

```
src/app/api/
├── my-feature/
│   ├── route.ts          # GET /api/my-feature, POST /api/my-feature
│   └── [id]/
│       └── route.ts      # GET/PATCH/DELETE /api/my-feature/[id]
```

---

## Testing

### Linting

```bash
# Run ESLint
bun run lint

# Fix auto-fixable issues
bunx eslint . --fix
```

### Type Checking

```bash
# Check TypeScript types
bunx tsc --noEmit
```

### Manual Testing Checklist

When making changes, verify:

- [ ] Landing page loads correctly
- [ ] Sign up flow creates a user
- [ ] Login flow authenticates (when implemented)
- [ ] Dashboard displays stats
- [ ] Alerts list loads and filters work
- [ ] Brief view renders correctly
- [ ] Monitoring charts display data
- [ ] Workflow board shows task columns
- [ ] Mobile responsive (check at 375px, 768px, 1024px widths)
- [ ] No console errors in browser DevTools

---

## Reporting Bugs

### Before Reporting

1. Check existing issues to avoid duplicates
2. Try to reproduce the bug with the latest version (`cbup update`)
3. Run `cbup doctor` to check for system-level issues

### Bug Report Template

When opening a bug report, include:

```markdown
## Bug Description
Clear description of the bug.

## Steps to Reproduce
1. Go to...
2. Click on...
3. See error...

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: Ubuntu 22.04
- Browser: Chrome 120
- CBUP Version: 0.2.0
- Install Method: bare-metal / Docker

## Logs
```
cbup logs 50
```

## Screenshots
If applicable, add screenshots.
```

---

## Requesting Features

### Feature Request Template

```markdown
## Feature Description
Clear description of the proposed feature.

## Motivation
Why is this feature needed? What problem does it solve?

## Proposed Solution
How would you like this feature to work?

## Alternatives Considered
Any alternative approaches you've thought about.

## Additional Context
Any other relevant information (mockups, references, etc.).
```

---

## Release Process

### Release Checklist

1. Ensure all PRs for the release are merged
2. Update `package.json` version
3. Update `docs/CHANGELOG.md` with the new version
4. Create a git tag: `git tag v0.3.0`
5. Push the tag: `git push origin v0.3.0`
6. Verify the 1-click installer works: `./install.sh --yes`
7. Verify Docker build works: `docker build -t cbup .`

### Post-Release

1. Update the README if needed
2. Announce the release via GitHub Discussions
3. Update the roadmap

---

Thank you for contributing to Cyber Brief Unified Platform!
