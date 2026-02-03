# ClaudeKit Distribution System - Project Overview & PDR

**Product Development Requirements Document**

## Executive Summary

The ClaudeKit Distribution System is a secure, modular platform for packaging and distributing Claude Code configurations, skills, workflows, and agents to development teams. It provides multiple installation methods with comprehensive security controls and automatic configuration management.

**Version:** 2.0
**Status:** Active
**Last Updated:** 2026-02-03

## Project Objectives

### Primary Goals
1. **Secure Distribution**: Safely deliver ClaudeKit products to users without exposing credentials
2. **Multiple Installation Methods**: Support various deployment scenarios (HTTP server, GitHub, global)
3. **Automated Configuration**: Auto-inject security rules and normalize paths for end-user environments
4. **Production-Ready**: Comprehensive error handling, validation, and backup mechanisms

### Success Criteria
- Users can install ClaudeKit in < 2 minutes via any method
- Zero credential exposure in public-facing scripts
- Automatic backups before any installation
- Clear error messages for all failure scenarios
- Support for at least 2 concurrent product distributions

## Functional Requirements

### F1: Multi-Product Distribution
- **Description**: Support distribution of multiple ClaudeKit products
- **Products**: claudekit-engineer, claudekit-marketing (extensible)
- **Manifest**: Auto-generate JSON manifest listing available products
- **Version Tracking**: Track and display version for each product

### F2: Installation Methods
- **F2.1 HTTP Server**: Serve releases via local nginx, download via curl
- **F2.2 GitHub One-Liner**: Download directly from GitHub with authentication
- **F2.3 Global Installer**: Setup ClaudeKit to ~/.claude for all projects
- **F2.4 Download-Only Mode**: Download without automatic installation

### F3: Security & Compliance
- **F3.1 Command Deny List**: Block 60+ dangerous command patterns
- **F3.2 Credential Isolation**: Never expose tokens in public scripts
- **F3.3 Automatic Backup**: Backup ~/.claude before modifications
- **F3.4 Shared Rules Injection**: Auto-inject security rules into agent files
- **F3.5 Path Normalization**: Convert relative paths to absolute ~/.claude paths

### F4: Post-Installation Configuration
- **F4.1 Settings Update**: Fix relative paths in settings.json
- **F4.2 CLAUDE.md Copy**: Copy project-specific instructions
- **F4.3 Shared Rules Copy**: Copy and inject _shared-rules.md
- **F4.4 Permissions**: Make all scripts executable

### F5: Administrative Tools
- **F5.1 GitHub Release Fetch**: Download latest releases using GitHub API
- **F5.2 Version Cleanup**: Remove old versions, keep latest only
- **F5.3 Manifest Generation**: Create manifest.json for all products
- **F5.4 HTTP Trigger**: Remote trigger for download.sh via HTTP

## Non-Functional Requirements

### NFR1: Performance
- Installation completes in < 120 seconds (including download)
- Manifest loading < 2 seconds
- HTTP trigger response < 5 seconds

### NFR2: Reliability
- Support macOS (Bash 3.2+) and Linux environments
- Graceful failure with clear error messages
- Automatic cleanup of temporary files
- Dependency checking before execution

### NFR3: Maintainability
- Clear separation: admin (private) vs. public scripts
- Comprehensive comments for complex logic
- Consistent error codes and exit statuses
- JSON/Bash/Python standards compliance

### NFR4: Security
- No hardcoded credentials in public repository
- All shell scripts use `set -e` (exit on error)
- Command validation in deny list covers common attacks
- Permissions set correctly (700 for private, 755 for executables)

### NFR5: Scalability
- Support any number of products via manifest
- Docker containers for easy scaling
- HTTP trigger supports concurrent requests
- Efficient zip extraction and file operations

## Technical Architecture

### Component Overview

```
┌─────────────────────────────────────────────┐
│  Admin Tools (Private)                       │
│  ─────────────────────────────────           │
│  • download.sh (GitHub API client)          │
│  • Scripts in ~/.claude (shared rules)      │
└────────────┬────────────────────────────────┘
             │ (Generates releases/)
             ▼
┌─────────────────────────────────────────────┐
│  Distribution Server                        │
│  ─────────────────────────────────           │
│  • nginx:4567 (static file server)          │
│  • trigger-server:4568 (HTTP trigger)       │
│  • releases/ (packaged products)            │
└────────────┬────────────────────────────────┘
             │ (Serves via HTTP)
             ▼
┌─────────────────────────────────────────────┐
│  Client Installation (Public)               │
│  ─────────────────────────────────           │
│  • install-claudekit.sh (main installer)    │
│  • install-claudekit-curl.sh (one-liner)    │
│  • install-claudekit-global.sh (dev setup)  │
└─────────────────────────────────────────────┘
```

### Key Design Decisions

1. **Separate Private/Public Scripts**
   - Admin scripts contain GitHub tokens (never public)
   - Public installer has zero credential requirements
   - Reduces security surface area

2. **Docker for Simplicity**
   - nginx for fast static file serving
   - Python trigger server for remote execution
   - Easy to deploy, scale, and maintain

3. **Fallback Parsing Without jq**
   - Public scripts work with grep/sed if jq unavailable
   - Reduces dependencies on end-user systems
   - Bash 3.2+ compatibility for macOS

4. **Manifest-Driven Distribution**
   - Single source of truth for available products
   - Simplifies product selection UI
   - Easy to add new products

## Data Flow

### Installation Flow
```
User runs install script
         │
         ├─ Check dependencies (curl, unzip)
         │
         ├─ Fetch manifest.json from server
         │
         ├─ Parse products (with jq or fallback)
         │
         ├─ Display menu, get user selection
         │
         ├─ Download selected .zip from server
         │
         ├─ Extract to temp directory
         │
         ├─ Backup existing ~/.claude
         │
         ├─ Copy .claude to ~/.claude
         │
         ├─ Fix settings.json paths
         │
         ├─ Copy CLAUDE.md and _shared-rules.md
         │
         └─ Inject shared rules into agents
```

### Admin Release Flow
```
Admin runs download.sh
         │
         ├─ Check GITHUB_TOKEN set
         │
         ├─ For each product:
         │   ├─ Fetch latest release from GitHub API
         │   ├─ Download .zip file
         │   ├─ Clean old versions
         │   └─ Track version number
         │
         └─ Generate manifest.json with all versions
```

## Security Model

### Threat: Malicious Command Execution
**Control**: Command deny list in settings.json
- Blocks patterns like `rm -rf /`, `curl | bash`, `eval`
- Covers file destruction, disk attacks, RCE, database drops
- Updated with new threat patterns

### Threat: Credential Exposure
**Control**: Credential isolation
- Private admin scripts contain tokens (never in public scripts)
- Public installer has zero token requirements
- Shared rules injected only after installation

### Threat: Data Loss
**Control**: Automatic backups
- Existing ~/.claude backed up before installation
- Backup named with timestamp: `.claude-backup-YYYYMMDD-HHMMSS`
- Installation fails if backup fails

### Threat: Path Injection
**Control**: Path normalization
- settings.json converted to absolute ~/.claude paths
- All relative paths resolved before execution
- No dynamic path construction

## Deployment Scenarios

### Scenario 1: Small Team (5-10 developers)
- Run distribution server on admin machine
- Share server IP with team members
- Users install via: `curl -fsSL http://<ip>:4567/install-claudekit.sh | bash`
- Admin runs `download.sh` weekly to fetch latest

### Scenario 2: Large Organization (100+ developers)
- Deploy Docker containers to internal server farm
- Load balance across multiple instances
- Automated CI/CD triggers `download.sh` on release
- Users install via corporate package manager

### Scenario 3: Open Source (GitHub-based)
- Use GitHub one-liner: `GITHUB_TOKEN=xxx bash <(curl ...)`
- No local server needed
- Users install from release gists
- GitHub handles distribution and caching

### Scenario 4: Development (Local Machine)
- Run `install-claudekit-global.sh` on dev machine
- Installs to ~/.claude for all projects
- Simple one-command setup

## Success Metrics

| Metric | Target | Status |
|--------|--------|--------|
| Installation success rate | > 98% | ✓ |
| Installation time | < 120 sec | ✓ |
| Zero credential exposure | 100% | ✓ |
| Command deny list coverage | > 60 patterns | ✓ |
| Multi-product support | ≥ 2 products | ✓ |
| Documentation completeness | > 80% coverage | In Progress |
| Test coverage | > 70% | Planned |

## Dependencies

### External
- **curl**: Download from HTTP/HTTPS servers
- **unzip**: Extract .zip archives
- **bash**: Shell scripting (3.2+ compatibility required)
- **jq** (optional): JSON parsing (fallback to grep/sed)

### Runtime
- **Docker** (optional): For distribution server
- **Python 3.11+** (optional): For trigger server
- **nginx** (optional): For static file serving

### Internal
- **GitHub API**: For fetching releases (admin only)
- **settings.json**: Security configuration
- **_shared-rules.md**: Security rules template
- **CLAUDE.md**: Project instructions template

## Constraints & Limitations

1. **Bash Compatibility**: Must support macOS Bash 3.2 (no newer features)
2. **Network Dependent**: Installation requires internet access
3. **Token Management**: Admin must manage GitHub token lifecycle
4. **File Size**: Typical releases are 5-15MB (consider network bandwidth)
5. **Single Product Per Session**: Users install one product per run

## Future Enhancements

1. **Multiple Product Installation**: Install 2+ products in single run
2. **Auto-Update Checker**: Notify users of available updates
3. **Verification Hash**: SHA256 checksums for integrity verification
4. **Install Rollback**: Automated rollback on installation failure
5. **Analytics**: Track installation metrics and usage patterns
6. **Web UI**: Browser-based product selection and installation
7. **CI/CD Integration**: Automated release generation and deployment

## Glossary

- **ClaudeKit**: Claude Code configuration package (commands, skills, agents)
- **Product**: A specific ClaudeKit variant (engineer, marketing, etc.)
- **Release**: Versioned .zip distribution of a product
- **Manifest**: JSON file listing available products and versions
- **Trigger**: HTTP endpoint to remotely execute download.sh
- **Shared Rules**: Security constraints injected into agent files
- **Deny List**: Patterns of dangerous commands that are blocked

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | 2026-02-03 | Initial comprehensive PDR document |
| 1.0 | 2025-12-30 | Project kickoff |
