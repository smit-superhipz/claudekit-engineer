# ClaudeKit Distribution System - Code Standards

## Overview

This document defines coding conventions, security practices, and quality standards for the ClaudeKit Distribution System. All contributors MUST follow these standards.

## Bash Shell Scripting Standards

### 1. Script Headers

**Required header for all bash scripts:**
```bash
#!/bin/bash

#===============================================================================
# Script Name
# Description of what this script does
# PRIVATE or PUBLIC indicator
# Usage instructions if applicable
#===============================================================================

set -e  # Exit on error
```

**Example:**
```bash
#!/bin/bash

#===============================================================================
# ClaudeKit Public Installer
# Downloads and installs ClaudeKit from local HTTP server
# PUBLIC - NO GitHub token - Safe to distribute
# Usage: curl -fsSL http://<server>/install-claudekit.sh | bash
#===============================================================================

set -e
```

### 2. Exit Codes

**Standard exit codes (1-10 range):**
```bash
EXIT_SUCCESS=0
EXIT_SERVER_UNREACHABLE=1
EXIT_MANIFEST_FAILED=2
EXIT_DOWNLOAD_FAILED=3
EXIT_UNZIP_FAILED=4
EXIT_INSTALL_FAILED=5
```

**Define at top of script, use consistently:**
```bash
if [ $? -ne 0 ]; then
    exit $EXIT_DOWNLOAD_FAILED
fi
```

### 3. Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Variables | `SCREAMING_SNAKE_CASE` | `GITHUB_TOKEN`, `PRODUCT_COUNT`, `OUTPUT_DIR` |
| Constants | `SCREAMING_SNAKE_CASE` | `API_BASE="https://api.github.com"` |
| Functions | `snake_case` | `check_dependencies()`, `fetch_manifest()` |
| Local variables | `snake_case` | `http_code`, `temp_json`, `repo_name` |
| Arrays | `SCREAMING_SNAKE_CASE` | `PRODUCT_REPOS=()`, `PRODUCT_VERSIONS=()` |

### 4. Functions

**Function definition and documentation:**
```bash
# Description of what function does
# Parameters: $1 = description, $2 = description
# Returns: exit code (0 = success)
function_name() {
    local param1="$1"
    local param2="$2"

    # Implementation
    return 0
}
```

**Example:**
```bash
# Download release zip from URL
# Parameters: $1 = repo name, $2 = version, $3 = zipball URL
# Returns: 0 on success, 1 on failure
download_release_zip() {
    local repo_name="$1"
    local version="$2"
    local zipball_url="$3"

    print_info "Downloading ${repo_name} ${version}..."

    if ! curl -fSL -o "output.zip" "$zipball_url"; then
        print_error "Download failed"
        return 1
    fi

    print_success "Downloaded successfully"
    return 0
}
```

### 5. Variable Quoting

**Always quote variables to prevent word splitting:**

❌ **Incorrect:**
```bash
cp $file $dir        # Word splitting breaks if $file has spaces
rm -rf $path/*       # Dangerous glob expansion
```

✓ **Correct:**
```bash
cp "$file" "$dir"    # Safe with spaces in path
rm -rf "$path"/*     # Explicit path handling
```

**Exception: Control structures can be unquoted:**
```bash
if [ -n "$var" ]; then  # Quotes for clarity
if [ -f "$file" ]; then
for file in "$files"; do
```

### 6. Error Handling

**Use trap for cleanup:**
```bash
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT
```

**Use set -e with explicit error handling:**
```bash
set -e  # Exit on any error

# Use || true to allow errors in specific cases
command_that_might_fail || true

# Explicit error checking
if ! command_that_must_succeed; then
    print_error "Critical operation failed"
    exit $EXIT_FAILED
fi
```

### 7. Conditionals

**Preferred style ([ ] for POSIX compatibility):**
```bash
# File/directory tests
if [ -f "$file" ]; then      # File exists
if [ -d "$dir" ]; then       # Directory exists
if [ -z "$var" ]; then       # Variable is empty
if [ -n "$var" ]; then       # Variable is not empty
if [ "$var" = "value" ]; then # String equality

# Arithmetic
if [ "$count" -eq 0 ]; then  # Equal
if [ "$count" -gt 5 ]; then  # Greater than
if [ "$count" -lt 10 ]; then # Less than
```

**Pattern matching (use [[ ]] for advanced features):**
```bash
if [[ "$line" == *"pattern"* ]]; then
if [[ "$file" == *.sh ]]; then
if [[ "$var" =~ ^[0-9]+$ ]]; then  # Regex
```

### 8. Loops

**Prefer C-style for with arrays:**
```bash
for ((i=0; i<PRODUCT_COUNT; i++)); do
    echo "${PRODUCT_REPOS[$i]}"
done
```

**Use while for line-by-line reading:**
```bash
while IFS= read -r line; do
    echo "$line"
done < "$file"
```

**Use for with glob patterns:**
```bash
for file in "$DIR"/*.sh; do
    [ -f "$file" ] || continue
    chmod +x "$file"
done
```

### 9. Command Substitution

**Prefer $(command) over `command` (backticks):**

❌ **Avoid:**
```bash
version=`git describe --tags`
```

✓ **Correct:**
```bash
version=$(git describe --tags)
```

### 10. Comments

**Comment complex logic and non-obvious decisions:**
```bash
# Check if same version exists
if [ -f "$output_file" ]; then
    if [ "$FORCE_DOWNLOAD" = false ]; then
        print_info "Already exists: $(basename "$output_file")"
        # Still clean old versions even if skipping download
        clean_old_versions "$repo_name" "$version"
        return 0
    fi
fi
```

**Do NOT comment obvious code:**
```bash
❌ # Set count to zero
count=0

✓ count=0  # Self-explanatory
```

## Python Standards (trigger-server.py)

### 1. Style

Follow PEP 8 with these adjustments:
- Line length: 100 characters (not 79)
- Indent: 4 spaces
- Use type hints where possible

### 2. Structure

```python
#!/usr/bin/env python3
"""Module docstring describing purpose."""

import module1
import module2
from package import Class

CONSTANT = "value"

class ClassName:
    """Class docstring."""

    def __init__(self):
        """Initialize instance."""
        pass

    def method_name(self):
        """Method docstring."""
        pass

def function_name():
    """Function docstring."""
    pass

if __name__ == "__main__":
    main()
```

### 3. Error Handling

```python
try:
    result = subprocess.run(
        ["bash", SCRIPT],
        capture_output=True,
        text=True,
        timeout=300
    )
except subprocess.TimeoutExpired:
    handle_timeout()
except Exception as e:
    log_error(str(e))
    return {"error": str(e)}
```

## JSON Configuration Standards

### 1. Formatting

```json
{
  "key": "value",
  "nested": {
    "property": "value",
    "array": [
      "item1",
      "item2"
    ]
  }
}
```

**Rules:**
- 2-space indentation
- No trailing commas
- Double quotes for all strings
- Newline at end of file

### 2. settings.json Structure

```json
{
  "hooks": {},
  "permissions": {
    "allow": [],
    "deny": [
      "// ====== CATEGORY NAME ======",
      "Bash(pattern:details)",
      "Bash(another-pattern:details)"
    ]
  }
}
```

**Deny pattern format: `Bash(command-pattern:details)`**

## Security Standards

### 1. Credential Management

**DO:**
- ✓ Use environment variables for sensitive data (GITHUB_TOKEN)
- ✓ Document required credentials in comments
- ✓ Never hardcode tokens in public scripts
- ✓ Use private scripts for credential-containing code

**DON'T:**
- ✗ Hardcode API keys, tokens, or passwords
- ✗ Log sensitive data to output
- ✗ Store credentials in git repositories
- ✗ Expose credentials in error messages

### 2. Input Validation

**Always validate user input:**
```bash
get_product_selection() {
    local selection
    while true; do
        read -p "Enter selection [0-$PRODUCT_COUNT]: " selection < /dev/tty

        # Validate: must be numeric, in range
        if [[ "$selection" =~ ^[0-9]+$ ]] && \
           [ "$selection" -ge 0 ] && \
           [ "$selection" -le "$PRODUCT_COUNT" ]; then
            return 0
        fi

        print_error "Invalid selection"
    done
}
```

### 3. Safe File Operations

**Use secure temp directories:**
```bash
# DON'T: TEMP_DIR="/tmp/script"
# DO:
TEMP_DIR="/tmp/script-$$-$RANDOM"
mkdir -p "$TEMP_DIR"
```

**Always cleanup temporary files:**
```bash
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    [ -f "$MANIFEST_FILE" ] && rm -f "$MANIFEST_FILE"
}

trap cleanup EXIT
```

**Use safe file permissions:**
```bash
# Private files (no world access)
chmod 700 "$PRIVATE_FILE"

# Executables (owner execute)
chmod 755 "$SCRIPT_FILE"
```

### 4. URL & Network Safety

**Validate HTTP responses:**
```bash
http_code=$(curl -sS -w "%{http_code}" -o "$output" "$url")

case "$http_code" in
    200) print_success "Downloaded" ;;
    404) print_error "Not found" ;;
    401|403) print_error "Access denied" ;;
    *) print_error "HTTP $http_code" ;;
esac
```

**Use HTTPS for all external URLs:**
```bash
# DON'T: API_BASE="http://api.example.com"
# DO:
API_BASE="https://api.github.com"
```

### 5. Dependency Isolation

**Only execute trusted scripts:**
```bash
# DON'T: curl -fsSL "$url" | bash
# DO: Download, validate, then execute
curl -fsSL "$url" -o "$script"
if ! validate_signature "$script"; then
    exit 1
fi
bash "$script"
```

## Code Review Checklist

Before submitting code, verify:

### Security
- [ ] No hardcoded credentials or tokens
- [ ] All user input validated
- [ ] File operations use safe paths
- [ ] Error messages don't leak sensitive data
- [ ] Dangerous commands blocked in settings.json

### Correctness
- [ ] Set -e at top of scripts
- [ ] All variables properly quoted
- [ ] All functions documented
- [ ] Error codes consistent and documented
- [ ] Exit codes used correctly

### Compatibility
- [ ] Bash 3.2+ compatible (no newer syntax)
- [ ] Works on macOS and Linux
- [ ] curl and unzip available
- [ ] No hardcoded absolute paths (except ~/.claude)

### Maintainability
- [ ] Functions under 80 lines
- [ ] Complex logic commented
- [ ] Consistent naming conventions
- [ ] No code duplication
- [ ] Clear error messages

### Documentation
- [ ] Script header with purpose
- [ ] Function documentation
- [ ] Exit codes defined
- [ ] Usage examples included
- [ ] Dependencies listed

## Testing Standards

### Manual Testing

**Installation script testing:**
```bash
# Test 1: Basic installation
BASE_URL=http://localhost:4567 bash install-claudekit.sh

# Test 2: Download-only mode
BASE_URL=http://localhost:4567 bash install-claudekit.sh

# Test 3: Backup behavior
mkdir -p ~/.claude && touch ~/.claude/test.txt
bash install-claudekit.sh
# Verify ~/.claude-backup-* created

# Test 4: No jq fallback
(mv $(which jq) $(which jq).bak; bash install-claudekit.sh)
mv $(which jq).bak $(which jq)
```

**Admin script testing:**
```bash
# Test 1: Download with token
export GITHUB_TOKEN=ghp_xxxx
./scripts/download.sh

# Test 2: Force re-download
./scripts/download.sh --force

# Test 3: Manifest generation
ls -la scripts/releases/manifest.json
```

### Automated Testing (Future)

Planned test suite:
- Unit tests for parsing functions
- Integration tests for installation flow
- Security tests for deny list patterns
- Compatibility tests on multiple systems

## Documentation Standards

### README.md

Must include:
- Project overview
- Quick start instructions
- Installation methods
- Architecture diagram
- File inventory
- Troubleshooting section

### Code Comments

**Comment blocks for sections:**
```bash
#-------------------------------------------------------------------------------
# Section Name
#-------------------------------------------------------------------------------
```

**Inline comments for complex logic:**
```bash
# Initialize array for tracking downloads (bash 3.2+ compatible)
declare -a DOWNLOADED_VERSIONS
```

## Deprecation & Breaking Changes

**When making breaking changes:**
1. Add deprecation warning to old code
2. Update documentation with migration guide
3. Support both old and new for 1 release cycle
4. Remove old code in next major version

**Example:**
```bash
if [ "$OLD_FLAG" = true ]; then
    print_warning "Flag --old is deprecated, use --new instead"
    NEW_FLAG=true
fi
```

## Version Control Practices

### Commit Messages

Follow conventional commits:
```
feat: add support for new product type
fix: handle empty manifest gracefully
docs: update installation instructions
chore: update dependencies
refactor: extract common functions
```

### Branching

```
main          - Production-ready code
develop       - Integration branch
feature/xyz   - Feature branches
fix/xyz       - Bug fix branches
```

## Tools & Linting

### ShellCheck

Verify bash scripts with ShellCheck:
```bash
shellcheck scripts/*.sh
```

Fix common issues:
- Unquoted variables
- Missing error handling
- Inefficient patterns

### Pre-commit Hook

Recommended .git/hooks/pre-commit:
```bash
#!/bin/bash
shellcheck scripts/*.sh || exit 1
python3 -m py_compile scripts/trigger-server.py || exit 1
```

## Performance Guidelines

### Optimize for:
1. **Installation speed** - < 120 seconds total
2. **Manifest loading** - < 2 seconds
3. **File operations** - Batch when possible

### Avoid:
- Unnecessary loops
- Repeated file reads
- External command calls in loops
- Large string concatenations

## Related Documentation

- [Project Overview & PDR](./project-overview-pdr.md) - Requirements
- [Codebase Summary](./codebase-summary.md) - File descriptions
- [System Architecture](./system-architecture.md) - Design details
- [Deployment Guide](./deployment-guide.md) - Setup instructions
