# ClaudeKit Distribution System - System Architecture

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ClaudeKit Ecosystem                             │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  TIER 1: RELEASE GENERATION (Admin-Only, Private)                    │
│  ────────────────────────────────────────────────                    │
│  ┌──────────────────────────────────────────────────────┐            │
│  │ download.sh (Admin Script)                          │            │
│  │ • Requires: GITHUB_TOKEN                           │            │
│  │ • Queries: GitHub API /repos/{owner}/{repo}/...    │            │
│  │ • Outputs: releases/*.zip files                    │            │
│  │ • Generates: releases/manifest.json                │            │
│  └─────────────────────┬────────────────────────────────┘            │
│                        │                                               │
│                   (PRIVATE)                                            │
│                        ▼                                               │
│  ┌──────────────────────────────────────────────────────┐            │
│  │ releases/                                            │            │
│  │ ├─ claudekit-engineer-v2.0.0.zip                   │            │
│  │ ├─ claudekit-marketing-v1.5.0.zip                  │            │
│  │ └─ manifest.json                                   │            │
│  └──────────────────────────────────────────────────────┘            │
│                                                                        │
│─────────────────────────────────────────────────────────────────────│
│                                                                        │
│  TIER 2: DISTRIBUTION SERVER (Public Read-Only)                     │
│  ─────────────────────────────────────────────                     │
│  ┌──────────────────────────────────────────────────────┐            │
│  │ Docker Services                                      │            │
│  │                                                      │            │
│  │ Service 1: nginx:alpine (4567)                     │            │
│  │ ├─ GET /releases/manifest.json                     │            │
│  │ ├─ GET /releases/*.zip                             │            │
│  │ └─ GET /install-claudekit.sh                       │            │
│  │                                                      │            │
│  │ Service 2: trigger-server.py (4568)                │            │
│  │ ├─ GET /trigger-download → execute download.sh    │            │
│  │ └─ GET /health → status check                      │            │
│  └──────────────────────────────────────────────────────┘            │
│                                                                        │
│─────────────────────────────────────────────────────────────────────│
│                                                                        │
│  TIER 3: CLIENT INSTALLATION (Public, No Auth Required)             │
│  ──────────────────────────────────────────────────────            │
│  ┌──────────────────────────────────────────────────────┐            │
│  │ install-claudekit.sh (Public Installer)            │            │
│  │ • No credentials needed                            │            │
│  │ • Downloads from server (BASE_URL env var)         │            │
│  │ • Installs to ~/.claude/                           │            │
│  │ • Backs up existing ~/.claude                      │            │
│  │ • Injects shared rules                             │            │
│  └──────────────────────────────────────────────────────┘            │
│                                                                        │
│  Alternative installers:                                             │
│  • install-claudekit-curl.sh (GitHub one-liner)                     │
│  • install-claudekit-global.sh (Local dev setup)                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Admin Release Generation

```
┌─────────────────────────────────────────────────────────┐
│ download.sh (Admin Script)                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ INPUT: GITHUB_TOKEN (environment variable)             │
│                                                         │
│ PROCESS:                                                │
│                                                         │
│  1. check_token()                                       │
│     └─ Validate GITHUB_TOKEN is set                    │
│                                                         │
│  2. check_dependencies()                                │
│     └─ Verify curl available                           │
│                                                         │
│  3. For each product in PRODUCT_REPOS:                 │
│     │                                                   │
│     ├─ fetch_latest_release()                          │
│     │  └─ curl https://api.github.com/repos/.../      │
│     │     releases/latest \                            │
│     │     -H "Authorization: token $GITHUB_TOKEN"      │
│     │                                                   │
│     ├─ parse_json_file() (extract version)             │
│     │                                                   │
│     ├─ download_release_zip()                          │
│     │  └─ curl https://.../zipball_url -o file.zip   │
│     │                                                   │
│     ├─ clean_old_versions()                            │
│     │  └─ rm old-version.zip files                     │
│     │                                                   │
│     └─ Track version in DOWNLOADED_VERSIONS[]          │
│                                                         │
│  4. generate_manifest()                                │
│     └─ Create releases/manifest.json with all versions │
│                                                         │
│ OUTPUT: releases/manifest.json + *.zip files           │
│         Ready for distribution server                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2. Distribution Server

```
┌──────────────────────────────────────────────────────┐
│ Docker Compose (docker-compose.yml)                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│ SERVICE 1: nginx:alpine                             │
│ ├─ Listen: 0.0.0.0:4567                            │
│ ├─ Root: ./releases/                                │
│ ├─ Static content delivery:                         │
│ │  ├─ /manifest.json                                │
│ │  ├─ /claudekit-engineer-v2.0.0.zip               │
│ │  └─ /claudekit-marketing-v1.5.0.zip              │
│ │                                                   │
│ │ HTTP Flow:                                        │
│ │  GET /releases/manifest.json                      │
│ │    └─ nginx serves releases/manifest.json         │
│ │                                                   │
│ │  GET /releases/product.zip                        │
│ │    └─ nginx serves releases/product.zip           │
│ │                                                   │
│ └─ Status: 200 OK, Content-Type: application/json   │
│                                                      │
│ SERVICE 2: trigger-server (Python 3.11)             │
│ ├─ Listen: 0.0.0.0:4568                            │
│ ├─ Endpoints:                                       │
│ │  ├─ GET /trigger-download                        │
│ │  │  ├─ Execute: bash /app/download.sh             │
│ │  │  ├─ Timeout: 300 seconds                       │
│ │  │  └─ Return: JSON with success/stdout/stderr    │
│ │  │                                                │
│ │  └─ GET /health                                  │
│ │     └─ Return: {"status": "ok"}                   │
│ │                                                   │
│ └─ Environment: GITHUB_TOKEN (for download.sh)      │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 3. Public Installation Flow

```
┌──────────────────────────────────────────────────────────────┐
│ install-claudekit.sh (Public Installer)                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ INPUT: BASE_URL (environment or hardcoded)                  │
│        No credentials needed                                │
│                                                              │
│ PROCESS:                                                     │
│                                                              │
│  1. check_dependencies()                                     │
│     ├─ Verify curl available                                │
│     ├─ Verify unzip available                               │
│     └─ Detect jq (optional, for fast JSON parsing)          │
│                                                              │
│  2. create_temp_dir()                                        │
│     └─ TEMP_DIR="/tmp/claudekit-install-$$-$RANDOM"        │
│                                                              │
│  3. fetch_manifest()                                         │
│     └─ curl $BASE_URL/releases/manifest.json                │
│                                                              │
│  4. parse_manifest()                                         │
│     ├─ Use jq if available: jq '.products[]'                │
│     └─ Fallback: grep/sed parsing                           │
│                                                              │
│  5. show_product_menu() + get_product_selection()           │
│     └─ Interactive menu for user selection                  │
│                                                              │
│  6. download_zip()                                           │
│     └─ curl $BASE_URL/releases/$SELECTED_FILE.zip           │
│                                                              │
│  7. extract_archive()                                        │
│     ├─ unzip -q $TEMP_DIR/claudekit.zip                     │
│     └─ Find extracted .claude directory                     │
│                                                              │
│  8. Installation decision:                                   │
│     ├─ Mode 1: run_installer()                              │
│     │  ├─ Backup existing ~/.claude                         │
│     │  ├─ cp -r .claude ~/.claude                           │
│     │  ├─ fix_settings_paths() - convert relative→absolute  │
│     │  ├─ copy_claude_md() - copy CLAUDE.md                │
│     │  ├─ copy_shared_rules() - copy _shared-rules.md       │
│     │  └─ inject_shared_rules() - add to agent files        │
│     │                                                        │
│     └─ Mode 2: run_download_only()                          │
│        └─ cp -r .claude $PWD/.claude                        │
│                                                              │
│  9. cleanup()                                                │
│     └─ rm -rf $TEMP_DIR                                     │
│                                                              │
│ OUTPUT: ~/.claude/ installed and configured                 │
│         OR ./.claude/ in current directory                  │
│                                                              │
│ EXIT CODES:                                                  │
│   0 - Success                                                │
│   1 - Server unreachable                                     │
│   2 - Manifest download failed                              │
│   3 - Zip download failed                                   │
│   4 - Extraction failed                                     │
│   5 - Installation failed                                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### Complete Installation Workflow

```
User Machine                    Server                    GitHub
    │                            │                          │
    ├──────────────────────────→ │                          │
    │  BASE_URL set              │                          │
    │                            │                          │
    └─→ check_dependencies()     │                          │
    │   (curl, unzip, jq)        │                          │
    │                            │                          │
    ├──────────────────────────→ GET /manifest.json        │
    │                            │──→ nginx:4567           │
    │  manifest.json             │←── 200 OK               │
    │←──────────────────────────┤                          │
    │                            │                          │
    └─→ parse_manifest()         │                          │
    │   (jq or grep/sed)         │                          │
    │                            │                          │
    ├─→ show_product_menu()      │                          │
    │   User selects product     │                          │
    │                            │                          │
    ├──────────────────────────→ GET /releases/product.zip │
    │                            │──→ nginx:4567           │
    │  product.zip               │←── 200 OK               │
    │←──────────────────────────┤                          │
    │                            │                          │
    ├─→ extract_archive()        │                          │
    │   (unzip)                  │                          │
    │                            │                          │
    ├─→ Backup ~/.claude         │                          │
    │   (if exists)              │                          │
    │                            │                          │
    ├─→ Copy .claude             │                          │
    │   → ~/.claude              │                          │
    │                            │                          │
    ├─→ fix_settings_paths()     │                          │
    │   (~/.claude/settings.json)│                          │
    │                            │                          │
    ├─→ inject_shared_rules()    │                          │
    │   (.claude/agents/*.md)    │                          │
    │                            │                          │
    └─→ ✓ Installation complete! │                          │
```

### Admin Release Generation Workflow

```
Admin Machine               GitHub API              Release Storage
      │                        │                          │
      ├─→ export GITHUB_TOKEN  │                          │
      │   (authenticate)       │                          │
      │                        │                          │
      ├──────────────────────→ GET /repos/claudekit/     │
      │                        claudekit-engineer/       │
      │                        releases/latest           │
      │                        │                          │
      │  {"tag_name": "v2.0.0" │                          │
      │   "zipball_url": "..."}│                          │
      │←──────────────────────┤                          │
      │                        │                          │
      ├─→ parse version        │                          │
      │   (v2.0.0)             │                          │
      │                        │                          │
      ├──────────────────────→ GET /...zipball           │
      │                        /v2.0.0                   │
      │                        │                          │
      │  claudekit-            │                          │
      │  engineer-v2.0.0.zip   │                          │
      │←──────────────────────┤                          │
      │                        │                          │
      ├──────────────────────────────────────────────────→
      │                                      Save to
      │                                      releases/
      │                                      Claude-engineer-
      │                                      v2.0.0.zip
      │                                                   │
      ├─→ clean_old_versions()                           │
      │   (rm old versions)                              │
      │                                                   │
      ├──────────────────────────────────────────────────→
      │                                      Generate
      │                                      manifest.json
      │                                      with all
      │                                      versions
      │                                                   │
      └─→ ✓ Release generation complete!
```

## Security Architecture

### 1. Credential Isolation

```
PRIVATE LAYER (Admin Only)
├─ download.sh (contains GitHub token access)
│  ├─ Requires: GITHUB_TOKEN env var
│  ├─ Uses: GitHub API with authentication
│  └─ Produces: Signed release files
│
├─ trigger-server.py
│  ├─ Receives: GITHUB_TOKEN in docker-compose
│  ├─ Uses: For triggering download.sh
│  └─ Exposes: Only HTTP trigger endpoint
│
└─ _shared-rules.md (injected after installation)
   ├─ Contains: Security constraints
   └─ Applied: Only to installed instances

───────────────────────────────────────────────

PUBLIC LAYER (No Credentials)
├─ install-claudekit.sh
│  ├─ No: GITHUB_TOKEN required
│  ├─ No: API keys needed
│  └─ Uses: Public HTTP server (nginx)
│
├─ install-claudekit-curl.sh
│  ├─ Optional: GITHUB_TOKEN for GitHub access
│  └─ Can: Work without authentication
│
└─ install-claudekit-global.sh
   └─ No: Credentials required at any point
```

### 2. Command Execution Safety

```
settings.json (Deny List)
├─ File/System Destruction
│  ├─ Blocks: rm -rf /, rm -rf ~:*
│  ├─ Blocks: mv * /dev/null:*
│  └─ Covers: 15 patterns
│
├─ Disk Destruction
│  ├─ Blocks: dd if=/dev/zero of=/dev/*
│  └─ Covers: 5 patterns
│
├─ Permission Attacks
│  ├─ Blocks: chmod -R 777 /
│  └─ Covers: 4 patterns
│
├─ Remote Code Execution
│  ├─ Blocks: curl * | bash
│  ├─ Blocks: eval $*
│  └─ Covers: 8 patterns
│
├─ Database Destruction
│  ├─ Blocks: DROP DATABASE
│  └─ Covers: 8 patterns
│
└─ ... (15+ categories, 60+ total patterns)
```

### 3. Path Safety

```
Relative Path → Absolute Path Conversion
├─ Input: ".claude/hooks/settings.json"
│
├─ Process:
│  └─ sed 's|\.claude/hooks/|~/.claude/hooks/|g'
│
└─ Output: "~/.claude/hooks/settings.json"
   └─ Expanded: "/Users/user/.claude/hooks/settings.json"

Safety Properties:
✓ No dynamic path construction
✓ No glob expansion in paths
✓ All paths pre-validated before use
✓ Backup paths include timestamp
```

## Performance Characteristics

### Installation Performance

| Operation | Typical Time | Notes |
|-----------|-------------|-------|
| Dependency check | < 1 sec | curl/unzip check |
| Manifest download | 0.5-2 sec | Depends on network |
| JSON parsing | < 0.5 sec | jq or grep/sed |
| Zip download | 10-30 sec | 5-15MB file, network |
| Extraction | 1-3 sec | unzip performance |
| Path fixing | < 0.5 sec | sed substitution |
| Rule injection | 0.5-1 sec | File operations |
| **Total** | **15-60 sec** | Typically ~30 sec |

### Server Performance

| Operation | Throughput | Notes |
|-----------|-----------|-------|
| Manifest serving | 1000s req/sec | Static file, nginx |
| Zip download | Limited by bandwidth | ~5MB/sec typical |
| Trigger requests | 10 req/sec | Single-threaded Python |
| Concurrent downloads | 100+ | nginx handles concurrency |

## Scalability Considerations

### Current Design
- Single Docker Compose setup (development/small teams)
- Direct filesystem access to releases/
- Sequential processing in Python trigger server

### Scaling Options

1. **Load Balancing** (100-1000 users)
   ```
   Load Balancer → nginx replicas (4567)
   ↓
   Shared volume (releases/)
   ```

2. **CDN Distribution** (1000+ users)
   ```
   GitHub Releases → CloudFront/Akamai
   ↓
   Users (fastest mirror)
   ```

3. **Message Queue** (Async releases)
   ```
   API → Queue (RabbitMQ/SQS)
   ↓
   Workers (download.sh)
   ↓
   S3/GCS storage
   ```

## Failure Modes & Recovery

### Failure: Manifest Not Found (404)

```
Error: Manifest not found at http://server:4567/releases/manifest.json
Causes:
├─ Server not running
├─ download.sh not executed
└─ releases/ directory missing

Recovery:
1. Start server: docker-compose up -d
2. Generate releases: ./scripts/download.sh
3. Verify: curl http://localhost:4567/releases/manifest.json
4. Retry installation
```

### Failure: Download Interrupted

```
Error: Extracted directory not found
Causes:
├─ Network interrupted during download
├─ Incomplete zip file
└─ Unzip failure

Recovery:
1. Retry: Temp dir cleaned, re-run installer
2. Manual recovery: rm ~/.claude-backup-*, restart
3. Check space: ensure /tmp has 20MB+ free
```

### Failure: Installation Fails

```
Error: Failed to copy .claude folder
Causes:
├─ Permission denied on ~/.claude-backup
├─ Insufficient disk space
└─ Corrupted .claude in archive

Recovery:
1. Check backup: ls ~/.claude-backup-*
2. Restore: mv ~/.claude-backup-LATEST ~/.claude
3. Verify permissions: chmod 700 ~/.claude
```

## Monitoring & Observability

### Health Checks

**Server health endpoint:**
```bash
curl http://localhost:4568/health
# {"status": "ok"}
```

**Manifest availability:**
```bash
curl -I http://localhost:4567/releases/manifest.json
# HTTP/1.1 200 OK
```

**Recent releases:**
```bash
ls -lt scripts/releases/*.zip | head -5
```

### Logging

**Installer logs** (stdout during execution):
```
✓ Dependencies OK (curl, unzip)
ℹ Fetching product list from server...
✓ Product manifest loaded
ℹ Downloading claudekit-engineer-v2.0.0.zip...
✓ Download complete
...
✓ Installation complete!
```

**Server logs** (Docker):
```bash
# nginx logs
docker logs claudekit-releases | tail -20

# trigger server logs
docker logs claudekit-trigger | tail -20
```

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md) - Requirements and design
- [Codebase Summary](./codebase-summary.md) - File descriptions
- [Code Standards](./code-standards.md) - Development standards
- [Deployment Guide](./deployment-guide.md) - Setup and operations
