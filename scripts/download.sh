#!/bin/bash

#===============================================================================
# ClaudeKit Private Admin Script - Download Releases
# Downloads latest releases from GitHub and caches them locally
# PRIVATE - Contains GitHub token - NEVER make public
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Exit Codes
#-------------------------------------------------------------------------------
EXIT_SUCCESS=0
EXIT_MISSING_TOKEN=1
EXIT_API_FAILED=2
EXIT_DOWNLOAD_FAILED=3

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
# Token: Use env var or hardcode (NEVER commit hardcoded token to public repo)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="claudekit"
API_BASE="https://api.github.com"

# Script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/releases"

# Products (indexed arrays for bash 3.2 compatibility)
PRODUCT_REPOS=("claudekit-engineer" "claudekit-marketing")
PRODUCT_COUNT=${#PRODUCT_REPOS[@]}

# Flags
FORCE_DOWNLOAD=false

#-------------------------------------------------------------------------------
# Print Functions
#-------------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      ClaudeKit Admin - Download Releases v1.0                ║${NC}"
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

check_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GITHUB_TOKEN not set"
        echo ""
        echo "Usage:"
        echo "  export GITHUB_TOKEN=ghp_xxxx"
        echo "  ./download-releases.sh"
        echo ""
        exit $EXIT_MISSING_TOKEN
    fi
    print_success "GitHub token detected"
}

check_dependencies() {
    local missing=()

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing[*]}"
        exit $EXIT_DOWNLOAD_FAILED
    fi

    print_success "Dependencies OK (curl)"

    if command -v jq &> /dev/null; then
        print_info "jq detected - using for JSON parsing"
        HAS_JQ=true
    else
        print_info "jq not found - using grep/sed fallback"
        HAS_JQ=false
    fi
}

# Parse JSON field from file
parse_json_file() {
    local json_file="$1"
    local field="$2"

    if [ "$HAS_JQ" = true ]; then
        jq -r ".$field" "$json_file" 2>/dev/null
    else
        grep -o "\"$field\": *\"[^\"]*\"" "$json_file" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'
    fi
}

#-------------------------------------------------------------------------------
# Core Functions
#-------------------------------------------------------------------------------

# Fetch latest release info, returns version
fetch_latest_release() {
    local repo_name="$1"
    local output_file="$2"
    local url="$API_BASE/repos/$REPO_OWNER/$repo_name/releases/latest"

    local http_code
    http_code=$(curl -sS \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -w "%{http_code}" \
        -o "$output_file" \
        "$url" 2>/dev/null)

    case "$http_code" in
        200)
            return 0
            ;;
        401)
            print_error "Authentication failed (401)"
            return 1
            ;;
        403)
            print_error "Access forbidden (403)"
            return 1
            ;;
        404)
            print_error "Not found (404) - No release for $repo_name"
            return 1
            ;;
        *)
            print_error "API request failed with HTTP $http_code"
            return 1
            ;;
    esac
}

# Clean old version files for a repo (keep only the new version)
clean_old_versions() {
    local repo_name="$1"
    local new_version="$2"
    local new_file="${repo_name}-${new_version}.zip"

    # Find all versioned files for this repo
    for old_file in "$OUTPUT_DIR"/${repo_name}-v*.zip; do
        [ -f "$old_file" ] || continue
        local filename=$(basename "$old_file")

        # Skip if it's the new version file
        if [ "$filename" = "$new_file" ]; then
            continue
        fi

        # Delete old version
        rm -f "$old_file"
        print_info "Removed old version: $filename"
    done
}

# Download release zip
download_release_zip() {
    local repo_name="$1"
    local version="$2"
    local zipball_url="$3"
    local output_file="$OUTPUT_DIR/${repo_name}-${version}.zip"

    # Check if same version exists
    if [ -f "$output_file" ]; then
        if [ "$FORCE_DOWNLOAD" = false ]; then
            print_info "Already exists: $(basename "$output_file") (use --force to re-download)"
            # Still clean old versions even if skipping download
            clean_old_versions "$repo_name" "$version"
            return 0
        fi
        # Force mode: will overwrite
        print_info "Force re-downloading: $(basename "$output_file")"
    fi

    print_info "Downloading ${repo_name} ${version}..."

    if ! curl -fSL \
        -H "Authorization: token $GITHUB_TOKEN" \
        -o "$output_file" \
        "$zipball_url"; then
        print_error "Download failed for $repo_name"
        return 1
    fi

    # Verify file
    if [ ! -s "$output_file" ]; then
        print_error "Downloaded file is empty"
        rm -f "$output_file"
        return 1
    fi

    # Clean old versions AFTER successful download
    clean_old_versions "$repo_name" "$version"

    print_success "Downloaded: $(basename "$output_file")"
    return 0
}

# Generate manifest.json
generate_manifest() {
    local manifest_file="$OUTPUT_DIR/manifest.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    print_info "Generating manifest.json..."

    # Build products array
    local products_json=""
    local first=true

    for i in "${!PRODUCT_REPOS[@]}"; do
        local repo="${PRODUCT_REPOS[$i]}"
        local version="${DOWNLOADED_VERSIONS[$i]:-}"
        local file="${repo}-${version}.zip"

        # Skip if no version (download failed)
        if [ -z "$version" ]; then
            continue
        fi

        if [ "$first" = true ]; then
            first=false
        else
            products_json+=","
        fi

        products_json+="
    {
      \"repo\": \"$repo\",
      \"version\": \"$version\",
      \"file\": \"$file\"
    }"
    done

    # Write manifest
    cat > "$manifest_file" << EOF
{
  "products": [$products_json
  ],
  "updated": "$timestamp"
}
EOF

    print_success "Generated: manifest.json"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                FORCE_DOWNLOAD=true
                shift
                ;;
            --help|-h)
                echo "Usage: ./download-releases.sh [--force]"
                echo ""
                echo "Options:"
                echo "  --force, -f    Force re-download even if files exist"
                echo ""
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    print_header

    # Pre-flight
    check_token
    check_dependencies

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    print_success "Output directory: $OUTPUT_DIR"

    echo ""

    # Track downloaded versions for manifest
    declare -a DOWNLOADED_VERSIONS

    # Process each product
    for i in "${!PRODUCT_REPOS[@]}"; do
        local repo="${PRODUCT_REPOS[$i]}"
        echo ""
        print_info "Processing: $repo"

        # Fetch release info
        local temp_json=$(mktemp)
        if ! fetch_latest_release "$repo" "$temp_json"; then
            rm -f "$temp_json"
            DOWNLOADED_VERSIONS[$i]=""
            continue
        fi

        # Extract version and zipball URL
        local version=$(parse_json_file "$temp_json" "tag_name")
        local zipball_url=$(parse_json_file "$temp_json" "zipball_url")
        rm -f "$temp_json"

        if [ -z "$version" ] || [ "$version" = "null" ]; then
            print_error "Could not parse version for $repo"
            DOWNLOADED_VERSIONS[$i]=""
            continue
        fi

        print_success "Found version: $version"

        # Download
        if ! download_release_zip "$repo" "$version" "$zipball_url"; then
            DOWNLOADED_VERSIONS[$i]=""
            continue
        fi

        DOWNLOADED_VERSIONS[$i]="$version"
    done

    echo ""

    # Generate manifest
    generate_manifest

    echo ""
    print_success "All done!"
    echo ""
    echo "Next steps:"
    echo "  1. Start HTTP server: cd releases && python3 -m http.server 8080"
    echo "  2. Users run: curl -fsSL http://<your-ip>:8080/install-claudekit.sh | bash"
    echo ""

    exit $EXIT_SUCCESS
}

main "$@"
