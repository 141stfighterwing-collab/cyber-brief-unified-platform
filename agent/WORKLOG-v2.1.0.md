# CBUP Agent v2.1.0 Worklog

---
Task ID: 2
Agent: Fix & Refactor Agent
Task: Fix 7 bugs, refactor CBUP-Agent.ps1 into modular sub-files, add company-specific signature support

Work Log:
- Read full 2,296-line CBUP-Agent.ps1 with byte-level analysis (hex dump verification)
- Identified Bugs 2 ([hashtable] missing) and 4 ([math] missing) as false positives
  caused by terminal ANSI escape sequence display eating [h/[m byte sequences
- Confirmed Bugs 1, 3, 5, 6, 7 as real code defects via hex-level byte verification
- Applied 5 real bug fixes to CBUP-Agent.ps1:
  - Bug 1 (line 703): Added null guard `$proc.ExecutablePath -and` before `.StartsWith()`
  - Bug 3 (line 1422): Fixed pipeline-in-hashtable: `| Select-Object -ExpandProperty` to `.TotalSeconds`
  - Bug 5 (line 1270): Removed broken `$maxLen` reference and double `-ne` condition
  - Bug 6 (line 1271): Reordered `$minLen -ne "Unknown"` check before `[int]$minLen` cast
  - Bug 7 (lines 690, 767): Fixed over-escaped regex from `\\\\Temp` (4 backslashes) to `\\Temp` (2)
- Created agent/modules/ directory with 16 modular sub-files:
  1. CBUP-Logging.ps1 (102 lines)
  2. CBUP-Registry.ps1 (66 lines)
  3. CBUP-API.ps1 (132 lines)
  4. CBUP-Discovery.ps1 (98 lines)
  5. CBUP-Telemetry.ps1 (140 lines)
  6. CBUP-EDR-Process.ps1 (91 lines)
  7. CBUP-EDR-Service.ps1 (74 lines)
  8. CBUP-EDR-Port.ps1 (93 lines)
  9. CBUP-EDR-Autorun.ps1 (187 lines)
  10. CBUP-EDR-Vulnerability.ps1 (227 lines)
  11. CBUP-EDR-Full.ps1 (37 lines)
  12. CBUP-C2Commands.ps1 (434 lines)
  13. CBUP-Service.ps1 (151 lines)
  14. CBUP-Registration.ps1 (125 lines)
  15. CBUP-Signature.ps1 (149 lines) -- NEW
- Rewrote main CBUP-Agent.ps1 as 336-line entry point with dot-source module loading
- Updated version 2.0.1 to 2.1.0 in CBUP-Agent.ps1, CBUP-Agent-Tray.ps1, build-exe.ps1

Stage Summary:
- 5 real bugs fixed; 2 identified as false positives (terminal display artifacts)
- 2,296-line monolith split into 16 modules + 336-line entry point (all under 1200 lines)
- New CBUP-Signature.ps1 provides tenant/company-bound SHA256 fingerprinting via registry persistence
- Version bumped to 2.1.0 across all agent PS1 files
- No TypeScript/Next.js files were modified
- Original CBUP-Agent.ps1.bak preserved as backup
