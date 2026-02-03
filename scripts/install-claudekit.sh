#!/bin/bash

#===============================================================================
# ClaudeKit Public Installer
# Downloads and installs ClaudeKit from local HTTP server
# PUBLIC - NO GitHub token - Safe to distribute
# Usage: curl -fsSL http://<server>/install-claudekit.sh | bash
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Exit Codes
#-------------------------------------------------------------------------------
EXIT_SUCCESS=0
EXIT_SERVER_UNREACHABLE=1
EXIT_MANIFEST_FAILED=2
EXIT_DOWNLOAD_FAILED=3
EXIT_UNZIP_FAILED=4
EXIT_INSTALL_FAILED=5

#-------------------------------------------------------------------------------
# Colors
#-------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Config
#-------------------------------------------------------------------------------
# BASE_URL: Set this before serving, or pass via env var
# Example: BASE_URL=http://192.168.1.100:8080 curl -fsSL .../install-claudekit.sh | bash
BASE_URL="${BASE_URL:-http://192.168.68.63:4567}"

TEMP_DIR=""
MANIFEST_FILE=""

# Products (populated from manifest)
declare -a PRODUCT_REPOS
declare -a PRODUCT_VERSIONS
declare -a PRODUCT_FILES
PRODUCT_COUNT=0
SELECTED_PRODUCT=""
INSTALL_MODE=""

#-------------------------------------------------------------------------------
# Print Functions
#-------------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ClaudeKit Installer v2.0                            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

check_dependencies() {
    local missing=()

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if ! command -v unzip &> /dev/null; then
        missing+=("unzip")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo "Please install them first."
        exit $EXIT_DOWNLOAD_FAILED
    fi

    print_success "Dependencies OK (curl, unzip)"

    if command -v jq &> /dev/null; then
        HAS_JQ=true
    else
        HAS_JQ=false
    fi
}

create_temp_dir() {
    TEMP_DIR="/tmp/claudekit-install-$$-$RANDOM"
    mkdir -p "$TEMP_DIR"
}

cleanup() {
    if [ -n "$MANIFEST_FILE" ] && [ -f "$MANIFEST_FILE" ]; then
        rm -f "$MANIFEST_FILE"
    fi
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

#-------------------------------------------------------------------------------
# Manifest Functions
#-------------------------------------------------------------------------------

fetch_manifest() {
    print_info "Fetching product list from server..."

    MANIFEST_FILE=$(mktemp)
    local manifest_url="$BASE_URL/releases/manifest.json"

    local http_code
    http_code=$(curl -sS \
        -w "%{http_code}" \
        -o "$MANIFEST_FILE" \
        "$manifest_url" 2>/dev/null) || true

    case "$http_code" in
        200)
            print_success "Product manifest loaded"
            ;;
        000)
            print_error "Cannot connect to server: $BASE_URL"
            echo ""
            echo "Make sure the server is running:"
            echo "  cd releases && python3 -m http.server 8080"
            echo ""
            exit $EXIT_SERVER_UNREACHABLE
            ;;
        404)
            print_error "Manifest not found at $manifest_url"
            echo ""
            echo "Run download-releases.sh first to generate manifest.json"
            echo ""
            exit $EXIT_MANIFEST_FAILED
            ;;
        *)
            print_error "Failed to fetch manifest (HTTP $http_code)"
            exit $EXIT_MANIFEST_FAILED
            ;;
    esac
}

parse_manifest() {
    if [ "$HAS_JQ" = true ]; then
        parse_manifest_jq
    else
        parse_manifest_fallback
    fi

    if [ "$PRODUCT_COUNT" -eq 0 ]; then
        print_error "No products found in manifest"
        exit $EXIT_MANIFEST_FAILED
    fi

    print_success "Found $PRODUCT_COUNT product(s)"
}

parse_manifest_jq() {
    PRODUCT_COUNT=$(jq '.products | length' "$MANIFEST_FILE")

    for ((i=0; i<PRODUCT_COUNT; i++)); do
        PRODUCT_REPOS[$i]=$(jq -r ".products[$i].repo" "$MANIFEST_FILE")
        PRODUCT_VERSIONS[$i]=$(jq -r ".products[$i].version" "$MANIFEST_FILE")
        PRODUCT_FILES[$i]=$(jq -r ".products[$i].file" "$MANIFEST_FILE")
    done
}

parse_manifest_fallback() {
    # Simple fallback parsing for manifest without jq
    # Extract product count by counting "repo" occurrences
    PRODUCT_COUNT=$(grep -o '"repo"' "$MANIFEST_FILE" | wc -l | tr -d ' ')

    # Parse each product (basic extraction)
    local idx=0
    while IFS= read -r line; do
        if [[ "$line" == *'"repo"'* ]]; then
            PRODUCT_REPOS[$idx]=$(echo "$line" | sed 's/.*"repo": *"\([^"]*\)".*/\1/')
        elif [[ "$line" == *'"version"'* ]]; then
            PRODUCT_VERSIONS[$idx]=$(echo "$line" | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        elif [[ "$line" == *'"file"'* ]]; then
            PRODUCT_FILES[$idx]=$(echo "$line" | sed 's/.*"file": *"\([^"]*\)".*/\1/')
            ((idx++))
        fi
    done < "$MANIFEST_FILE"
}

#-------------------------------------------------------------------------------
# Menu Functions
#-------------------------------------------------------------------------------

show_product_menu() {
    echo ""
    echo -e "${BLUE}Select product to install:${NC}"
    echo ""

    for ((i=0; i<PRODUCT_COUNT; i++)); do
        local num=$((i + 1))
        local file="${PRODUCT_FILES[$i]}"
        echo -e "  [${num}] ${GREEN}${file}${NC}"
    done

    echo ""
    echo -e "  [0] Cancel installation"
    echo ""
}

get_product_selection() {
    local selection
    while true; do
        read -p "Enter selection [0-$PRODUCT_COUNT]: " selection < /dev/tty

        if [ "$selection" = "0" ]; then
            print_info "Installation cancelled"
            exit 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$PRODUCT_COUNT" ]; then
            SELECTED_PRODUCT=$((selection - 1))
            print_success "Selected: ${PRODUCT_FILES[$SELECTED_PRODUCT]}"
            return 0
        else
            print_error "Invalid selection. Enter 0-$PRODUCT_COUNT"
        fi
    done
}

show_mode_menu() {
    echo ""
    echo -e "${BLUE}Select action:${NC}"
    echo ""
    echo -e "  [1] Install to ~/.claude"
    echo -e "  [2] Download only (save to current directory)"
    echo ""
    echo -e "  [0] Cancel"
    echo ""
}

get_mode_selection() {
    local selection
    while true; do
        read -p "Enter selection [0-2]: " selection < /dev/tty

        case "$selection" in
            0)
                print_info "Installation cancelled"
                exit 0
                ;;
            1)
                INSTALL_MODE="install"
                print_success "Mode: Install to ~/.claude"
                return 0
                ;;
            2)
                INSTALL_MODE="download"
                print_success "Mode: Download only"
                return 0
                ;;
            *)
                print_error "Invalid selection. Enter 0, 1, or 2"
                ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# Download & Install Functions
#-------------------------------------------------------------------------------

download_zip() {
    local file="${PRODUCT_FILES[$SELECTED_PRODUCT]}"
    local url="$BASE_URL/releases/$file"

    print_info "Downloading ${file}..."
    echo "  URL: $url"
    echo ""

    local zip_file="$TEMP_DIR/claudekit.zip"

    if ! curl -fSL -o "$zip_file" "$url"; then
        print_error "Download failed"
        exit $EXIT_DOWNLOAD_FAILED
    fi

    if [ ! -s "$zip_file" ]; then
        print_error "Downloaded file is empty"
        exit $EXIT_DOWNLOAD_FAILED
    fi

    print_success "Download complete"
}

extract_archive() {
    print_info "Extracting archive..."

    local zip_file="$TEMP_DIR/claudekit.zip"

    if ! unzip -q "$zip_file" -d "$TEMP_DIR"; then
        print_error "Extraction failed"
        exit $EXIT_UNZIP_FAILED
    fi

    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)

    if [ -z "$EXTRACTED_DIR" ]; then
        print_error "Could not find extracted directory"
        exit $EXIT_UNZIP_FAILED
    fi

    print_success "Extracted successfully"
}

run_installer() {
    print_info "Installing ClaudeKit to ~/.claude..."

    local source_claude="$EXTRACTED_DIR/.claude"
    local target_claude="$HOME/.claude"

    if [ ! -d "$source_claude" ]; then
        print_error ".claude folder not found in release"
        exit $EXIT_INSTALL_FAILED
    fi

    # Backup existing
    if [ -d "$target_claude" ]; then
        local backup_dir="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
        print_warning "Existing ~/.claude found, backing up to $backup_dir"
        mv "$target_claude" "$backup_dir"
    fi

    # Copy
    if ! cp -r "$source_claude" "$target_claude"; then
        print_error "Failed to copy .claude folder"
        exit $EXIT_INSTALL_FAILED
    fi

    # Make scripts executable
    find "$target_claude" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$target_claude" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    print_success "ClaudeKit installed to ~/.claude"

    # Post-install steps
    fix_settings_paths "$target_claude"
    copy_claude_md "$target_claude"
    copy_shared_rules "$target_claude"
    inject_shared_rules "$target_claude"

    # Summary
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "ClaudeKit has been installed to ~/.claude"
    echo ""
    echo "Usage:"
    echo "  1. Open terminal in any project"
    echo "  2. Run: claude"
    echo "  3. Use commands: /plan, /cook, /fix, /test..."
    echo ""
}

run_download_only() {
    local source_claude="$EXTRACTED_DIR/.claude"
    local target_dir="$(pwd)/.claude"

    if [ ! -d "$source_claude" ]; then
        print_error ".claude folder not found in release"
        exit $EXIT_INSTALL_FAILED
    fi

    if [ -d "$target_dir" ]; then
        print_warning ".claude folder already exists in current directory"
        read -p "Overwrite? [y/N]: " confirm < /dev/tty
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "Download cancelled"
            exit 0
        fi
        rm -rf "$target_dir"
    fi

    if ! cp -r "$source_claude" "$target_dir"; then
        print_error "Failed to copy .claude folder"
        exit $EXIT_INSTALL_FAILED
    fi

    find "$target_dir" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$target_dir" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    print_success "ClaudeKit downloaded to $(pwd)/.claude"

    copy_claude_md "$target_dir"
    copy_shared_rules "$target_dir"

    echo ""
    echo -e "${GREEN}Download complete!${NC}"
    echo ""
    echo "ClaudeKit saved to $(pwd)/.claude"
    echo ""
    echo "To install globally:"
    echo "  cp -r .claude ~/.claude"
    echo ""
}

#-------------------------------------------------------------------------------
# Post-Install Functions
#-------------------------------------------------------------------------------

fix_settings_paths() {
    local claude_dir="$1"
    local settings_file="$claude_dir/settings.json"

    if [ -f "$settings_file" ]; then
        print_info "Fixing settings.json paths..."

        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' 's|\.claude/hooks/|~/.claude/hooks/|g' "$settings_file"
            sed -i '' 's|\.claude/statusline\.cjs|~/.claude/statusline.cjs|g' "$settings_file"
        else
            sed -i 's|\.claude/hooks/|~/.claude/hooks/|g' "$settings_file"
            sed -i 's|\.claude/statusline\.cjs|~/.claude/statusline.cjs|g' "$settings_file"
        fi

        print_success "Settings paths updated"
    fi
}

copy_claude_md() {
    local target_dir="$1"
    local target_file="$target_dir/CLAUDE.md"

    if [ -f "$EXTRACTED_DIR/CLAUDE.md" ]; then
        cp "$EXTRACTED_DIR/CLAUDE.md" "$target_file"
        print_success "Copied CLAUDE.md"
    elif [ -f "$EXTRACTED_DIR/scripts/CLAUDE.md" ]; then
        cp "$EXTRACTED_DIR/scripts/CLAUDE.md" "$target_file"
        print_success "Copied CLAUDE.md"
    fi
}

copy_shared_rules() {
    local target_dir="$1"
    local target_file="$target_dir/_shared-rules.md"

    if [ -f "$EXTRACTED_DIR/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    elif [ -f "$EXTRACTED_DIR/scripts/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/scripts/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    elif [ -f "$EXTRACTED_DIR/.claude/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/.claude/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    fi
}

inject_shared_rules() {
    local agents_dir="$1/agents"
    local shared_rules_ref="**CRITICAL:** You MUST read and strictly follow ALL rules at \`~/.claude/_shared-rules.md\` before proceeding. NON-NEGOTIABLE."
    local marker="<!-- SHARED_RULES_INJECTED -->"
    local injected=0

    if [ ! -d "$agents_dir" ]; then
        return
    fi

    for file in "$agents_dir"/*.md; do
        [ -f "$file" ] || continue
        local filename=$(basename "$file")

        if [ "$filename" = "_shared-rules.md" ]; then
            continue
        fi

        if grep -q "$marker" "$file" 2>/dev/null; then
            continue
        fi

        echo "" >> "$file"
        echo "$marker" >> "$file"
        echo "" >> "$file"
        echo "---" >> "$file"
        echo "" >> "$file"
        echo "$shared_rules_ref" >> "$file"

        ((injected++))
    done

    if [ $injected -gt 0 ]; then
        print_success "Injected shared rules into $injected agent files"
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    print_header

    trap cleanup EXIT

    check_dependencies
    create_temp_dir

    echo ""

    fetch_manifest
    parse_manifest

    show_product_menu
    get_product_selection

    show_mode_menu
    get_mode_selection

    echo ""

    download_zip
    extract_archive

    echo ""

    if [ "$INSTALL_MODE" = "install" ]; then
        run_installer
    else
        run_download_only
    fi

    exit $EXIT_SUCCESS
}

main "$@"
