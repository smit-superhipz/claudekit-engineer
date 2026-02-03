#!/bin/bash

#===============================================================================
# ClaudeKit One-Liner Installer
# Download và cài đặt ClaudeKit từ private GitHub repo
# Usage: GITHUB_TOKEN=xxx curl -fsSL <gist-url> | bash
#===============================================================================

set -e  # Exit on error

#-------------------------------------------------------------------------------
# Exit Codes (theo design.md)
#-------------------------------------------------------------------------------
EXIT_SUCCESS=0
EXIT_MISSING_TOKEN=1
EXIT_API_FAILED=2
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
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Config
#-------------------------------------------------------------------------------
REPO_OWNER="claudekit"
REPO_NAME=""  # Set dynamically by product selection
API_BASE="https://api.github.com"
TEMP_DIR=""
RELEASE_JSON_FILE=""

#-------------------------------------------------------------------------------
# Products Config (using indexed arrays for bash 3.2 compatibility)
#-------------------------------------------------------------------------------
PRODUCT_NAMES=("" "ClaudeKit Engineer" "ClaudeKit Marketing")
PRODUCT_REPOS=("" "claudekit-engineer" "claudekit-marketing")
PRODUCT_VERSIONS=("" "" "")
PRODUCT_COUNT=2
SELECTED_PRODUCT=""
INSTALL_MODE=""  # "install" or "download"

#-------------------------------------------------------------------------------
# Print Functions
#-------------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        ClaudeKit Multi-Product Installer v1.1                ║${NC}"
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

# Check if GITHUB_TOKEN is set
check_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        GITHUB_TOKEN=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
        # print_error "GITHUB_TOKEN không được set"
        # echo ""
        # echo "Cách sử dụng:"
        # echo "  export GITHUB_TOKEN=ghp_xxxx"
        # echo "  curl -fsSL <gist-url> | bash"
        # echo ""
        # echo "Hoặc:"
        # echo "  GITHUB_TOKEN=ghp_xxxx bash -c \"\$(curl -fsSL <gist-url>)\""
        # echo ""
        # exit $EXIT_MISSING_TOKEN
    fi
    print_success "GitHub token detected"
}

# Check required dependencies
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

    # Optional: check for jq
    if command -v jq &> /dev/null; then
        print_info "jq detected - using for JSON parsing"
        HAS_JQ=true
    else
        print_info "jq not found - using grep/sed fallback"
        HAS_JQ=false
    fi
}

# Parse JSON field from file - uses jq if available, fallback to grep/sed
parse_json_file() {
    local json_file="$1"
    local field="$2"

    if [ "$HAS_JQ" = true ]; then
        jq -r ".$field" "$json_file" 2>/dev/null
    else
        # Fallback for simple field extraction
        grep -o "\"$field\": *\"[^\"]*\"" "$json_file" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
    fi
}

# Parse JSON file for zip download URL
# For private repos, always use zipball_url (works with token auth)
# Asset URLs (browser_download_url) don't work for private repos
parse_zip_url_file() {
    local json_file="$1"
    local url=""

    if [ "$HAS_JQ" = true ]; then
        # Use zipball_url (GitHub's API endpoint - works with private repos)
        url=$(jq -r '.zipball_url' "$json_file" 2>/dev/null)
    else
        url=$(grep -o '"zipball_url": *"[^"]*"' "$json_file" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    echo "$url"
}

#-------------------------------------------------------------------------------
# Product Selection Functions
#-------------------------------------------------------------------------------

# Fetch version for a specific repo (silent, returns version string)
fetch_repo_version() {
    local repo_name="$1"
    local url="$API_BASE/repos/$REPO_OWNER/$repo_name/releases/latest"
    local temp_file=$(mktemp)

    local http_code
    http_code=$(curl -sS \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -w "%{http_code}" \
        -o "$temp_file" \
        "$url" 2>/dev/null)

    if [ "$http_code" = "200" ]; then
        local version=$(parse_json_file "$temp_file" "tag_name")
        rm -f "$temp_file"
        echo "$version"
    else
        rm -f "$temp_file"
        echo "error"
    fi
}

# Display product selection menu
show_product_menu() {
    echo ""
    echo -e "${BLUE}Select product to install:${NC}"
    echo ""

    for i in $(seq 1 $PRODUCT_COUNT); do
        local name="${PRODUCT_NAMES[$i]}"
        local version="${PRODUCT_VERSIONS[$i]}"
        if [ "$version" = "error" ]; then
            echo -e "  [${i}] ${name} ${RED}(unavailable)${NC}"
        else
            echo -e "  [${i}] ${name} ${GREEN}(${version})${NC}"
        fi
    done

    echo ""
    echo -e "  [0] Cancel installation"
    echo ""
}

# Get user selection
get_product_selection() {
    local selection
    while true; do
        read -p "Enter selection [0-$PRODUCT_COUNT]: " selection < /dev/tty

        # Handle cancel
        if [ "$selection" = "0" ]; then
            print_info "Installation cancelled"
            exit 0
        fi

        # Validate numeric input and range
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$PRODUCT_COUNT" ]; then
            local version="${PRODUCT_VERSIONS[$selection]}"
            if [ "$version" = "error" ]; then
                print_error "Product unavailable. Please select another."
            else
                SELECTED_PRODUCT=$selection
                REPO_NAME="${PRODUCT_REPOS[$selection]}"
                print_success "Selected: ${PRODUCT_NAMES[$selection]}"
                return 0
            fi
        else
            print_error "Invalid selection. Enter 0-$PRODUCT_COUNT"
        fi
    done
}

# Show install mode menu
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

# Get install mode selection
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
# GitHub API Functions
#-------------------------------------------------------------------------------

# Fetch latest release info
fetch_latest_release() {
    print_info "Fetching latest release..."

    local url="$API_BASE/repos/$REPO_OWNER/$REPO_NAME/releases/latest"

    # Use temp file for JSON (handles Unicode/emoji in release body)
    RELEASE_JSON_FILE=$(mktemp)

    local http_code
    http_code=$(curl -sS \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -w "%{http_code}" \
        -o "$RELEASE_JSON_FILE" \
        "$url" 2>/dev/null)

    # Check HTTP status
    case "$http_code" in
        200)
            print_success "Release info fetched"
            ;;
        401)
            print_error "Authentication failed (401) - Token không hợp lệ"
            exit $EXIT_API_FAILED
            ;;
        403)
            print_error "Access forbidden (403) - Token không có quyền truy cập repo"
            exit $EXIT_API_FAILED
            ;;
        404)
            print_error "Not found (404) - Repo không tồn tại hoặc chưa có release"
            exit $EXIT_API_FAILED
            ;;
        *)
            print_error "API request failed with HTTP $http_code"
            exit $EXIT_API_FAILED
            ;;
    esac
}

# Get zip asset URL from release
get_zip_asset_url() {
    ZIP_URL=$(parse_zip_url_file "$RELEASE_JSON_FILE")

    if [ -z "$ZIP_URL" ] || [ "$ZIP_URL" = "null" ]; then
        print_error "No .zip asset found in release"
        echo "Release cần có file .zip trong assets"
        exit $EXIT_DOWNLOAD_FAILED
    fi

    # Get version for display
    local version=$(parse_json_file "$RELEASE_JSON_FILE" "tag_name")
    print_success "Found release: $version"
}

#-------------------------------------------------------------------------------
# Download & Extract Functions
#-------------------------------------------------------------------------------

# Create temp directory
create_temp_dir() {
    TEMP_DIR="/tmp/claudekit-install-$$-$RANDOM"
    mkdir -p "$TEMP_DIR"
    print_success "Created temp directory: $TEMP_DIR"
}

# Download zip asset
download_asset() {
    local version=$(parse_json_file "$RELEASE_JSON_FILE" "tag_name")

    print_info "Downloading ClaudeKit..."
    echo "  📦 Version: $version"
    echo "  🔗 URL: $ZIP_URL"
    echo ""

    local zip_file="$TEMP_DIR/claudekit.zip"

    # Different headers for zipball_url vs asset URL
    if [[ "$ZIP_URL" == *"/zipball/"* ]]; then
        # zipball_url - only needs auth, no special Accept header
        if ! curl -fSL \
            -H "Authorization: token $GITHUB_TOKEN" \
            -o "$zip_file" \
            "$ZIP_URL"; then
            print_error "Download failed"
            exit $EXIT_DOWNLOAD_FAILED
        fi
    else
        # Regular asset download
        if ! curl -fSL \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/octet-stream" \
            -o "$zip_file" \
            "$ZIP_URL"; then
            print_error "Download failed"
            exit $EXIT_DOWNLOAD_FAILED
        fi
    fi

    # Verify file exists and not empty
    if [ ! -s "$zip_file" ]; then
        print_error "Downloaded file is empty"
        exit $EXIT_DOWNLOAD_FAILED
    fi

    print_success "Download complete"
}

# Extract zip archive
extract_archive() {
    print_info "Extracting archive..."

    local zip_file="$TEMP_DIR/claudekit.zip"

    if ! unzip -q "$zip_file" -d "$TEMP_DIR"; then
        print_error "Extraction failed"
        exit $EXIT_UNZIP_FAILED
    fi

    # Find extracted folder (format: claudekit-owner-repo-hash)
    # Exclude TEMP_DIR itself and look for subdirectories
    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)

    if [ -z "$EXTRACTED_DIR" ]; then
        print_error "Could not find extracted directory"
        exit $EXIT_UNZIP_FAILED
    fi

    print_success "Extracted to: $(basename $EXTRACTED_DIR)"
}

# Cleanup temp files
cleanup() {
    # Remove JSON temp file
    if [ -n "$RELEASE_JSON_FILE" ] && [ -f "$RELEASE_JSON_FILE" ]; then
        rm -f "$RELEASE_JSON_FILE"
    fi
    # Remove temp directory
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    print_info "Cleaned up temp files"
}

#-------------------------------------------------------------------------------
# Installation Functions
#-------------------------------------------------------------------------------

# Install ClaudeKit to ~/.claude
run_installer() {
    print_info "Installing ClaudeKit to ~/.claude..."

    local source_claude="$EXTRACTED_DIR/.claude"
    local target_claude="$HOME/.claude"

    # Check source exists
    if [ ! -d "$source_claude" ]; then
        print_error ".claude folder not found in release"
        exit $EXIT_INSTALL_FAILED
    fi

    # Backup existing ~/.claude if exists
    if [ -d "$target_claude" ]; then
        local backup_dir="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
        print_warning "Existing ~/.claude found, backing up to $backup_dir"
        mv "$target_claude" "$backup_dir"
    fi

    # Copy .claude folder
    if ! cp -r "$source_claude" "$target_claude"; then
        print_error "Failed to copy .claude folder"
        exit $EXIT_INSTALL_FAILED
    fi

    # Make scripts executable
    find "$target_claude" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$target_claude" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    print_success "ClaudeKit installed to ~/.claude"

    # Fix settings.json paths to use absolute paths
    fix_settings_paths "$target_claude"

    # Copy additional files from scripts/
    copy_claude_md "$target_claude"
    copy_shared_rules "$target_claude"

    # Inject shared rules into agent files
    inject_shared_rules "$target_claude"

    # Show summary
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "ClaudeKit đã được cài đặt vào ~/.claude"
    echo ""
    echo "Cách sử dụng:"
    echo "  1. Mở terminal trong BẤT KỲ dự án nào"
    echo "  2. Chạy: claude"
    echo "  3. Sử dụng commands: /plan, /cook, /fix, /test..."
    echo ""
}

# Fix settings.json to use absolute paths for hooks
fix_settings_paths() {
    local claude_dir="$1"
    local settings_file="$claude_dir/settings.json"

    if [ -f "$settings_file" ]; then
        print_info "Fixing settings.json paths..."

        # Replace relative paths with absolute paths
        # .claude/hooks/ -> ~/.claude/hooks/
        # .claude/statusline.cjs -> ~/.claude/statusline.cjs
        if [ "$(uname)" = "Darwin" ]; then
            # macOS sed requires empty string for -i
            sed -i '' 's|\.claude/hooks/|~/.claude/hooks/|g' "$settings_file"
            sed -i '' 's|\.claude/statusline\.cjs|~/.claude/statusline.cjs|g' "$settings_file"
        else
            # Linux sed
            sed -i 's|\.claude/hooks/|~/.claude/hooks/|g' "$settings_file"
            sed -i 's|\.claude/statusline\.cjs|~/.claude/statusline.cjs|g' "$settings_file"
        fi

        print_success "Settings paths updated to use ~/.claude/"
    fi
}

# Copy CLAUDE.md to target (check root first, then scripts/)
copy_claude_md() {
    local target_dir="$1"
    local target_file="$target_dir/CLAUDE.md"

    # Check root first (release structure)
    if [ -f "$EXTRACTED_DIR/CLAUDE.md" ]; then
        cp "$EXTRACTED_DIR/CLAUDE.md" "$target_file"
        print_success "Copied CLAUDE.md"
    # Fallback to scripts/ (local dev structure)
    elif [ -f "$EXTRACTED_DIR/scripts/CLAUDE.md" ]; then
        cp "$EXTRACTED_DIR/scripts/CLAUDE.md" "$target_file"
        print_success "Copied CLAUDE.md"
    else
        print_warning "CLAUDE.md not found in release"
    fi
}

# Copy _shared-rules.md to target (check multiple locations)
copy_shared_rules() {
    local target_dir="$1"
    local target_file="$target_dir/_shared-rules.md"

    # Check root first
    if [ -f "$EXTRACTED_DIR/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    # Check scripts/
    elif [ -f "$EXTRACTED_DIR/scripts/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/scripts/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    # Check .claude/
    elif [ -f "$EXTRACTED_DIR/.claude/_shared-rules.md" ]; then
        cp "$EXTRACTED_DIR/.claude/_shared-rules.md" "$target_file"
        print_success "Copied _shared-rules.md"
    else
        print_warning "_shared-rules.md not found in release"
    fi
}

# Inject shared rules reference into all agent files
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

        # Skip shared rules file itself
        if [ "$filename" = "_shared-rules.md" ]; then
            continue
        fi

        # Skip if already injected
        if grep -q "$marker" "$file" 2>/dev/null; then
            continue
        fi

        # Append shared rules reference
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

# Download only - copy .claude folder to current directory
run_download_only() {
    local source_claude="$EXTRACTED_DIR/.claude"
    local target_dir="$(pwd)/.claude"

    # Check source exists
    if [ ! -d "$source_claude" ]; then
        print_error ".claude folder not found in release"
        exit $EXIT_INSTALL_FAILED
    fi

    # Check if target already exists
    if [ -d "$target_dir" ]; then
        print_warning ".claude folder already exists in current directory"
        read -p "Overwrite? [y/N]: " confirm < /dev/tty
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_info "Download cancelled"
            exit 0
        fi
        rm -rf "$target_dir"
    fi

    # Copy .claude folder to current directory
    if ! cp -r "$source_claude" "$target_dir"; then
        print_error "Failed to copy .claude folder"
        exit $EXIT_INSTALL_FAILED
    fi

    # Make scripts executable
    find "$target_dir" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$target_dir" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    print_success "ClaudeKit downloaded to $(pwd)/.claude"

    # Copy additional files from scripts/
    copy_claude_md "$target_dir"
    copy_shared_rules "$target_dir"

    # Show summary
    echo ""
    echo -e "${GREEN}Download complete!${NC}"
    echo ""
    echo "ClaudeKit đã được tải về $(pwd)/.claude"
    echo ""
    echo "Để cài đặt vào global:"
    echo "  cp -r .claude ~/.claude"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    print_header

    # Setup cleanup trap
    trap cleanup EXIT

    # Pre-flight checks
    check_token
    check_dependencies

    echo ""

    # Fetch versions for all products
    print_info "Fetching available versions..."
    for i in $(seq 1 $PRODUCT_COUNT); do
        local repo="${PRODUCT_REPOS[$i]}"
        PRODUCT_VERSIONS[$i]=$(fetch_repo_version "$repo")
    done

    # Check if at least one product is available
    local available_count=0
    for i in $(seq 1 $PRODUCT_COUNT); do
        if [ "${PRODUCT_VERSIONS[$i]}" != "error" ]; then
            available_count=$((available_count + 1))
        fi
    done

    if [ $available_count -eq 0 ]; then
        print_error "No products available. Check token permissions."
        exit $EXIT_API_FAILED
    fi

    # Show menu and get selection
    show_product_menu
    get_product_selection

    # Show mode menu and get selection
    show_mode_menu
    get_mode_selection

    echo ""

    # Fetch and parse release (uses REPO_NAME set by selection)
    fetch_latest_release
    get_zip_asset_url

    echo ""

    # Download and extract
    create_temp_dir
    download_asset
    extract_archive

    echo ""

    # Install or download based on mode
    if [ "$INSTALL_MODE" = "install" ]; then
        run_installer
    else
        run_download_only
    fi

    # Success (cleanup happens via trap)
    exit $EXIT_SUCCESS
}

# Run main
main "$@"
