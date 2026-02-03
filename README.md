# ClaudeKit Distribution System

A secure, multi-product distribution system for delivering ClaudeKit (Claude Code configurations, skills, workflows, and agents) to users.

## Overview

ClaudeKit Distribution System enables administrators to package and distribute ClaudeKit products (like `claudekit-engineer` and `claudekit-marketing`) to end users through multiple secure installation methods.

**Key Features:**
- **Multi-product support**: Distribute different ClaudeKit packages
- **Multiple installation methods**: Curl one-liner, local HTTP server, global installer
- **Security-first**: Comprehensive command deny list preventing destructive operations
- **Automatic backups**: Preserves existing configurations before installation
- **Shared rules injection**: Injects security rules into agent files
- **Path normalization**: Converts relative paths to absolute ~/.claude paths

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   ClaudeKit Distribution                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ADMIN SIDE                SERVER SIDE              CLIENT SIDE │
│  ──────────────           ─────────────             ───────────│
│  download.sh              nginx:4567                curl bash   │
│  ├─ Fetch GitHub          │                         │           │
│  ├─ Build manifest        └─ Serve releases/        ├─ GET      │
│  └─ Clean old versions       manifest.json          ├─ GET zip  │
│                                                     ├─ Extract  │
│  (Private, GitHub token)   trigger-server:4568     └─ Install  │
│                            └─ HTTP trigger            ~/.claude │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### For Users: Install ClaudeKit

**Option 1: From HTTP Server (simplest)**
```bash
BASE_URL=http://192.168.1.100:4567 bash <(curl -fsSL http://192.168.1.100:4567/install-claudekit.sh)
```

**Option 2: From GitHub (with token)**
```bash
GITHUB_TOKEN=ghp_xxxx bash <(curl -fsSL https://gist.github.com/.../raw)
```

**Option 3: Global Installation**
```bash
./install-claudekit-global.sh
```

### For Admins: Set Up Distribution Server

**1. Start Docker containers:**
```bash
cd /Volumes/Workplace/claudekit-engineer/scripts
export GITHUB_TOKEN=ghp_xxxx
docker-compose up -d
```

**2. Generate release manifest:**
```bash
./scripts/download.sh
```

**3. Server is ready:** Users can now install from `http://<your-ip>:4567`

**4. Trigger downloads remotely:**
```bash
curl http://192.168.1.100:4568/trigger-download
```

## Installation Methods

### Method 1: Local HTTP Server (Recommended for LANs)

Use when you want to serve releases from a private network without GitHub tokens.

```bash
# Start the server
cd scripts
docker-compose up -d

# Users install from
curl -fsSL http://<server-ip>:4567/install-claudekit.sh | bash
```

**Pros:** No tokens needed, fast downloads, simple
**Cons:** Requires running server, network-dependent

### Method 2: GitHub One-Liner (Direct from Repo)

Use for public distribution or when no local server available.

```bash
GITHUB_TOKEN=ghp_xxxx bash <(curl -fsSL <gist-url>)
```

**Pros:** No server required, works anywhere
**Cons:** Requires GitHub token, slower downloads

### Method 3: Global Installation

Use for development or single-machine setup.

```bash
./install-claudekit-global.sh
```

**Pros:** Simplest, no configuration
**Cons:** Only for the current machine

## File Inventory

| File | Purpose | Lines |
|------|---------|-------|
| `install-claudekit.sh` | Public installer (no token) | 550 |
| `download.sh` | Admin script - fetches from GitHub | 373 |
| `settings.json` | Security deny list config | 113 |
| `docker-compose.yml` | Docker setup (nginx + trigger) | 22 |
| `trigger-server.py` | HTTP trigger for downloads | 50 |
| `_shared-rules.md` | Shared rules (Vietnamese) | 22 |
| `CLAUDE.md` | Claude Code instructions | 104 |
| `install-claudekit-curl.sh` | One-liner GitHub installer | 710 |
| `install-claudekit-global.sh` | Global installer | 571 |

## Documentation

- **[Product Overview & PDR](./docs/project-overview-pdr.md)** - Requirements, features, and success criteria
- **[Codebase Summary](./docs/codebase-summary.md)** - File descriptions and module breakdown
- **[Code Standards](./docs/code-standards.md)** - Bash/Python conventions and best practices
- **[System Architecture](./docs/system-architecture.md)** - Detailed architecture and component flows
- **[Deployment Guide](./docs/deployment-guide.md)** - How to set up and run the distribution server

## Security

The system includes comprehensive security controls:

- **Command Deny List** (`settings.json`): Blocks 60+ dangerous command patterns
- **Credential Protection**: Never exposes API keys in public scripts
- **File Backup**: Auto-backups existing ~/.claude before installation
- **Path Validation**: Ensures all paths are absolute and safe
- **Shared Rules**: Injects security constraints into agent files

See [Code Standards](./docs/code-standards.md) for detailed security requirements.

## Development Workflow

```bash
# 1. Develop in scripts/
vim scripts/install-claudekit.sh

# 2. Build releases via download.sh
export GITHUB_TOKEN=ghp_xxxx
scripts/download.sh

# 3. Test with local server
cd scripts && docker-compose up -d

# 4. Users test installation
curl -fsSL http://localhost:4567/install-claudekit.sh | bash

# 5. Commit changes
git add .
git commit -m "feat: update installer functionality"
git push
```

## Troubleshooting

### "Cannot connect to server"
```bash
# Check if Docker containers are running
docker ps | grep claudekit

# Start containers
docker-compose up -d

# Test connectivity
curl http://localhost:4567/releases/manifest.json
```

### "Authentication failed (401)"
```bash
# Check GitHub token
echo $GITHUB_TOKEN

# Refresh token if expired
export GITHUB_TOKEN=ghp_new_token_here
./scripts/download.sh
```

### "Download failed"
```bash
# Check manifest exists
curl http://localhost:4567/releases/manifest.json

# Re-generate if needed
./scripts/download.sh --force
```

### "No products found"
Ensure `download.sh` was run successfully and releases are served:
```bash
ls -la scripts/releases/
curl http://localhost:4567/releases/
```

## Next Steps

1. Read [Project Overview & PDR](./docs/project-overview-pdr.md) for detailed requirements
2. Review [System Architecture](./docs/system-architecture.md) for design details
3. Follow [Deployment Guide](./docs/deployment-guide.md) to set up your distribution server
4. Check [Code Standards](./docs/code-standards.md) before contributing code changes

## Support

For issues or questions:
1. Check the relevant documentation file
2. Review script comments for implementation details
3. Check security settings in `settings.json`
4. Examine docker-compose.yml for container configuration
