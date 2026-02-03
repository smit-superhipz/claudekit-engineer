# ClaudeKit Distribution System - Codebase Summary

## Overview

The codebase consists of 9 shell scripts and configuration files totaling ~2,170 lines of code. The system is divided into three main components: admin tools (private), distribution server (Docker), and client installation scripts (public).

## Directory Structure

```
claudekit-engineer/
├── README.md                          # Project overview and quick start
├── scripts/
│   ├── install-claudekit.sh           # Main public installer (550 LOC)
│   ├── install-claudekit-curl.sh      # GitHub one-liner installer (710 LOC)
│   ├── download.sh                    # Admin release downloader (373 LOC)
│   ├── settings.json                  # Security deny list (113 LOC)
│   ├── docker-compose.yml             # Server Docker config (22 LOC)
│   ├── trigger-server.py              # HTTP trigger server (50 LOC)
│   ├── CLAUDE.md                      # Claude Code instructions (104 LOC)
│   ├── _shared-rules.md               # Shared security rules (22 LOC)
│   └── releases/                      # Generated releases (admin only)
├── docs/                              # Documentation
│   ├── project-overview-pdr.md        # PDR and requirements
│   ├── codebase-summary.md            # This file
│   ├── code-standards.md              # Coding conventions
│   ├── system-architecture.md         # Detailed architecture
│   └── deployment-guide.md            # Deployment instructions
└── install-claudekit-global.sh        # Global installer (571 LOC)
```

## File Descriptions

### Core Installers

#### `scripts/install-claudekit.sh` (550 LOC)
**Purpose**: Public-facing installer for HTTP server distribution

**Key Functions**:
- `check_dependencies()` - Verify curl and unzip available
- `fetch_manifest()` - Download manifest.json from server
- `parse_manifest()` - Parse products with jq or grep/sed fallback
- `show_product_menu()` - Display product selection UI
- `download_zip()` - Download selected product .zip
- `extract_archive()` - Unzip to temporary directory
- `run_installer()` - Install to ~/.claude with backup
- `run_download_only()` - Save to current directory without install
- `fix_settings_paths()` - Convert relative paths to absolute
- `inject_shared_rules()` - Add security rules to agent files

**Entry Point**: `main()` orchestrates entire flow

**Exit Codes**:
- `0` - Success
- `1` - Server unreachable
- `2` - Manifest download failed
- `3` - Zip download failed
- `4` - Extraction failed
- `5` - Installation failed

#### `scripts/install-claudekit-curl.sh` (710 LOC)
**Purpose**: GitHub-based one-liner installer for direct GitHub distribution

**Key Differences from install-claudekit.sh**:
- Requires GITHUB_TOKEN environment variable
- Fetches releases directly from GitHub API
- Supports both claudekit-engineer and claudekit-marketing products
- Interactive product selection menu
- Downloads latest release from GitHub

**Security**: Token must be set before running, never hardcoded in public versions

#### `install-claudekit-global.sh` (571 LOC)
**Purpose**: Simple global installer for development setup

**Key Functions**:
- `find_claudekit_root()` - Locate claudekit-engineer folder with .claude
- `install_to_global()` - Copy .claude to ~/.claude
- Post-install configuration same as other installers

**Use Case**: Single machine setup without network distribution

### Administrative Tools

#### `scripts/download.sh` (373 LOC)
**Purpose**: Private admin script to fetch releases from GitHub and generate manifest

**Key Functions**:
- `check_token()` - Verify GITHUB_TOKEN is set
- `fetch_latest_release()` - Query GitHub API for latest release info
- `download_release_zip()` - Download .zip file with caching
- `clean_old_versions()` - Remove previous versions (keep latest only)
- `generate_manifest()` - Create manifest.json for all products
- `parse_json_file()` - Extract JSON fields with jq or grep/sed

**Command-Line Arguments**:
- `--force`, `-f` - Force re-download even if file exists
- `--help`, `-h` - Show usage information

**Configuration**:
- `GITHUB_TOKEN` - Required GitHub personal access token
- `PRODUCT_REPOS` - Array of products to download
- `OUTPUT_DIR` - Output directory for releases

**Environment**: MUST run in admin environment with valid GitHub token

### Configuration Files

#### `settings.json` (113 LOC)
**Purpose**: Security configuration defining dangerous command patterns

**Structure**:
```json
{
  "hooks": {},
  "permissions": {
    "allow": [],
    "deny": [
      "Bash(pattern:details)",
      ...
    ]
  }
}
```

**Deny List Categories**:
- File/system destruction (rm -rf, mv to /dev/null)
- Disk destruction (dd to /dev/*, diskutil)
- Permission attacks (chmod/chown on root)
- Remote code execution (curl|bash, eval)
- Database destruction (DROP, TRUNCATE, FLUSHALL)
- Git destructive (reset --hard, push --force)
- Docker destructive (prune, rm, rmi)
- System control (shutdown, reboot)
- Credential exposure (read SSH keys, AWS credentials)
- Cloud destructive (aws s3 rm, ec2 terminate)

**Coverage**: 60+ dangerous patterns blocked

#### `docker-compose.yml` (22 LOC)
**Purpose**: Docker configuration for distribution server

**Services**:
1. **claudekit-server** (nginx:alpine)
   - Port: 4567
   - Serves static files from ./releases/
   - Role: HTTP server for installers

2. **trigger** (python:3.11-alpine)
   - Port: 4568
   - Runs trigger-server.py
   - Role: HTTP endpoint to trigger download.sh

**Environment**: `GITHUB_TOKEN` passed to trigger container

### Support Scripts

#### `scripts/trigger-server.py` (50 LOC)
**Purpose**: Simple HTTP trigger server for remote execution

**Endpoints**:
- `GET /trigger-download` - Execute download.sh and return result
- `GET /health` - Health check

**Response Format**:
```json
{
  "success": true,
  "timestamp": "2026-02-03T15:00:00",
  "stdout": "last 2000 chars of output",
  "stderr": "last 500 chars of errors"
}
```

**Timeout**: 300 seconds per request

#### `scripts/CLAUDE.md` (104 LOC)
**Purpose**: Claude Code instructions for project development

**Contents**:
- Language & Communication (Vietnamese requirement)
- Coding conventions (snake_case, camelCase, PascalCase, SCREAMING_SNAKE_CASE)
- ClaudeKit workflow compliance
- Workflow references
- Project context detection

#### `scripts/_shared-rules.md` (22 LOC)
**Purpose**: Shared security rules template injected into agent files

**Content**: Critical security rules in Vietnamese about following ~/.claude/_shared-rules.md

## Code Patterns

### Common Pattern 1: Color Output
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
```

### Common Pattern 2: JSON Parsing with Fallback
```bash
if [ "$HAS_JQ" = true ]; then
    parse_manifest_jq
else
    parse_manifest_fallback
fi
```

### Common Pattern 3: Temp File Management
```bash
TEMP_DIR="/tmp/claudekit-install-$$-$RANDOM"
mkdir -p "$TEMP_DIR"
trap cleanup EXIT
```

### Common Pattern 4: Dependency Checking
```bash
check_dependencies() {
    local missing=()
    [ -z "$(command -v curl)" ] && missing+=("curl")
    [ ${#missing[@]} -gt 0 ] && exit 1
}
```

### Common Pattern 5: HTTP Status Code Handling
```bash
http_code=$(curl -sS -w "%{http_code}" -o "$file" "$url")
case "$http_code" in
    200) handle_success ;;
    404) handle_not_found ;;
    *) handle_error ;;
esac
```

## Key Dependencies

### Required
- **curl** - HTTP requests (all installers, download script)
- **unzip** - Extract .zip archives (all installers)
- **bash** - Shell scripting (Bash 3.2+ for macOS compatibility)

### Optional
- **jq** - JSON parsing (fallback to grep/sed if unavailable)
- **docker** - Run distribution server
- **python 3.11+** - Run trigger server

### No External Languages
- Pure bash (no Ruby, Node.js, Go, etc.)
- Minimal Python for trigger server only
- Grep/sed fallback ensures compatibility

## Data Structures

### Manifest Format
```json
{
  "products": [
    {
      "repo": "claudekit-engineer",
      "version": "v2.0.0",
      "file": "claudekit-engineer-v2.0.0.zip"
    },
    {
      "repo": "claudekit-marketing",
      "version": "v1.5.0",
      "file": "claudekit-marketing-v1.5.0.zip"
    }
  ],
  "updated": "2026-02-03T15:00:00Z"
}
```

### Bash Array Pattern (Product Tracking)
```bash
declare -a PRODUCT_REPOS=("repo1" "repo2")
declare -a PRODUCT_VERSIONS=("v1.0.0" "v1.5.0")
declare -a PRODUCT_FILES=("repo1-v1.0.0.zip" "repo2-v1.5.0.zip")
PRODUCT_COUNT=2
```

## State & Configuration

### Environment Variables
- `BASE_URL` - HTTP server base URL (default: http://192.168.68.63:4567)
- `GITHUB_TOKEN` - GitHub authentication (required for admin)
- `HAS_JQ` - Auto-detected: true if jq available, false otherwise

### File Locations
- `~/.claude/` - User installation directory
- `~/.claude-backup-TIMESTAMP/` - Automatic backup
- `scripts/releases/` - Generated releases and manifest

### Configuration
- `settings.json` - Security deny list (static)
- `.claude/settings.json` - Per-user settings (modified during install)

## Code Quality Observations

### Strengths
✓ Comprehensive error handling with exit codes
✓ Defensive programming (check dependencies, validate input)
✓ Clear separation of concerns (public vs. private)
✓ Consistent naming conventions
✓ Extensive comments explaining logic
✓ Safe defaults (no eval, proper quoting)

### Areas for Enhancement
- Unit test coverage not present
- Some functions are long (> 50 lines)
- Limited inline documentation for complex regex
- No logging mechanism for troubleshooting
- Temp directory cleanup could be more robust

## Metrics

| Metric | Value |
|--------|-------|
| Total Lines of Code | ~2,170 |
| Number of Shell Scripts | 6 |
| Number of Config Files | 3 |
| Number of Python Scripts | 1 |
| Average Script Length | 362 LOC |
| Cyclomatic Complexity | Low-Medium |
| Test Coverage | 0% (no tests present) |
| Security Rules Enforced | 60+ patterns |

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md) - Detailed requirements
- [Code Standards](./code-standards.md) - Coding conventions and practices
- [System Architecture](./system-architecture.md) - Component design
- [Deployment Guide](./deployment-guide.md) - Setup and operations
