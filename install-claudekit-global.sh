#!/bin/bash

#===============================================================================
# ClaudeKit Global Installer
# Thiết lập ClaudeKit Engineer vào ~/.claude để sử dụng cho tất cả dự án
#===============================================================================

set -e  # Dừng script nếu có lỗi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_GLOBAL_DIR="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

# Find ClaudeKit Engineer folder (supports claudekit-engineer-x.x.x format)
find_claudekit_root() {
    local search_dir="$SCRIPT_DIR"

    # First check if script is inside claudekit-engineer*/scripts/
    local parent_dir="$(dirname "$SCRIPT_DIR")"
    local parent_name="$(basename "$parent_dir")"

    if [[ "$parent_name" == claudekit-engineer* ]] && [ -d "$parent_dir/.claude" ]; then
        echo "$parent_dir"
        return 0
    fi

    # Search in current directory for claudekit-engineer* folders
    local found_dirs=()
    while IFS= read -r -d '' dir; do
        if [ -d "$dir/.claude" ]; then
            found_dirs+=("$dir")
        fi
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type d -name "claudekit-engineer*" -print0 2>/dev/null)

    # Also search in parent directory
    while IFS= read -r -d '' dir; do
        if [ -d "$dir/.claude" ]; then
            found_dirs+=("$dir")
        fi
    done < <(find "$(dirname "$SCRIPT_DIR")" -maxdepth 1 -type d -name "claudekit-engineer*" -print0 2>/dev/null)

    if [ ${#found_dirs[@]} -eq 0 ]; then
        return 1
    elif [ ${#found_dirs[@]} -eq 1 ]; then
        echo "${found_dirs[0]}"
        return 0
    else
        # Multiple folders found, let user choose or pick latest
        echo -e "${YELLOW}Tìm thấy nhiều phiên bản ClaudeKit:${NC}" >&2
        local i=1
        for dir in "${found_dirs[@]}"; do
            echo "  $i) $(basename "$dir")" >&2
            ((i++))
        done
        echo "" >&2
        read -p "Chọn phiên bản (1-${#found_dirs[@]}): " choice >&2

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#found_dirs[@]} ]; then
            echo "${found_dirs[$((choice-1))]}"
            return 0
        else
            return 1
        fi
    fi
}

PROJECT_ROOT=""

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ClaudeKit Global Installer v1.0                     ║${NC}"
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

# Backup existing .claude folder
backup_existing() {
    if [ -d "$CLAUDE_GLOBAL_DIR" ]; then
        print_warning "Phát hiện thư mục ~/.claude đã tồn tại"
        echo ""
        echo "Bạn muốn làm gì?"
        echo "  1) Backup và thay thế hoàn toàn"
        echo "  2) Merge (giữ lại file cũ, thêm file mới)"
        echo "  3) Hủy cài đặt"
        echo ""
        read -p "Chọn (1/2/3): " choice

        case $choice in
            1)
                print_info "Đang backup vào $BACKUP_DIR..."
                mv "$CLAUDE_GLOBAL_DIR" "$BACKUP_DIR"
                print_success "Backup hoàn tất: $BACKUP_DIR"
                ;;
            2)
                MERGE_MODE=true
                print_info "Chế độ Merge: giữ file cũ, thêm file mới"
                ;;
            3)
                print_warning "Hủy cài đặt"
                exit 0
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                exit 1
                ;;
        esac
    fi
}

# Copy .claude folder
copy_claude_folder() {
    print_info "Đang copy thư mục .claude..."

    if [ "$MERGE_MODE" = true ]; then
        # Merge mode: copy without overwriting
        cp -rn "$PROJECT_ROOT/.claude/"* "$CLAUDE_GLOBAL_DIR/" 2>/dev/null || true
        # Copy hidden files
        cp -n "$PROJECT_ROOT/.claude/".* "$CLAUDE_GLOBAL_DIR/" 2>/dev/null || true
    else
        # Full copy
        mkdir -p "$CLAUDE_GLOBAL_DIR"
        cp -r "$PROJECT_ROOT/.claude/"* "$CLAUDE_GLOBAL_DIR/"
        # Copy hidden files
        cp "$PROJECT_ROOT/.claude/".* "$CLAUDE_GLOBAL_DIR/" 2>/dev/null || true
    fi

    print_success "Copy thư mục .claude hoàn tất"
}

# Copy settings.json for security permissions
copy_settings_json() {
    print_info "Đang copy settings.json (security permissions)..."

    local settings_src="$SCRIPT_DIR/settings.json"
    local settings_dest="$CLAUDE_GLOBAL_DIR/settings.json"

    if [ -f "$settings_src" ]; then
        if [ "$MERGE_MODE" = true ] && [ -f "$settings_dest" ]; then
            print_warning "File settings.json đã tồn tại"
            echo ""
            echo "Bạn muốn làm gì với settings.json?"
            echo "  1) Giữ file cũ (không thay đổi)"
            echo "  2) Thay thế bằng file mới (có deny list bảo mật)"
            echo ""
            read -p "Chọn (1/2): " settings_choice

            case $settings_choice in
                2)
                    cp "$settings_src" "$settings_dest"
                    print_success "Đã thay thế settings.json"
                    ;;
                *)
                    print_info "Giữ nguyên settings.json cũ"
                    ;;
            esac
        else
            cp "$settings_src" "$settings_dest"
            print_success "Copy settings.json hoàn tất"
        fi

        # Show what's being blocked
        echo ""
        echo -e "${YELLOW}Các lệnh nguy hiểm đã bị chặn:${NC}"
        echo "  • rm -rf / hoặc ~ (xóa hệ thống)"
        echo "  • Fork bombs (crash hệ thống)"
        echo "  • git reset --hard, git push --force"
        echo "  • Database DROP/TRUNCATE commands"
        echo "  • Docker destructive commands"
        echo "  • Cloud destructive (AWS, GCP, Azure)"
        echo "  • Credential exposure (SSH keys, AWS creds)"
        echo "  • Và nhiều lệnh nguy hiểm khác..."
        echo ""
    else
        print_warning "Không tìm thấy settings.json trong source"
    fi
}

# Copy CLAUDE.md from source
copy_claude_md() {
    print_info "Đang copy file CLAUDE.md..."

    local claude_md_src="$SCRIPT_DIR/CLAUDE.md"
    local claude_md_dest="$CLAUDE_GLOBAL_DIR/CLAUDE.md"

    if [ -f "$claude_md_src" ]; then
        if [ "$MERGE_MODE" = true ] && [ -f "$claude_md_dest" ]; then
            print_warning "File CLAUDE.md đã tồn tại"
            echo ""
            echo "Bạn muốn làm gì với CLAUDE.md?"
            echo "  1) Giữ file cũ (không thay đổi)"
            echo "  2) Thay thế bằng file mới"
            echo ""
            read -p "Chọn (1/2): " claude_choice

            case $claude_choice in
                2)
                    cp "$claude_md_src" "$claude_md_dest"
                    print_success "Đã thay thế CLAUDE.md"
                    ;;
                *)
                    print_info "Giữ nguyên CLAUDE.md cũ"
                    ;;
            esac
        else
            cp "$claude_md_src" "$claude_md_dest"
            print_success "Copy CLAUDE.md hoàn tất"
        fi
    else
        print_warning "Không tìm thấy CLAUDE.md trong source"
    fi
}

# Copy plans folder from ClaudeKit
copy_plans_folder() {
    print_info "Đang copy thư mục plans..."

    local plans_src="$PROJECT_ROOT/plans"
    local plans_dest="$CLAUDE_GLOBAL_DIR/plans"

    if [ -d "$plans_src" ]; then
        if [ "$MERGE_MODE" = true ] && [ -d "$plans_dest" ]; then
            print_warning "Thư mục plans/ đã tồn tại"
            echo ""
            echo "Bạn muốn làm gì với plans/?"
            echo "  1) Giữ folder cũ (không thay đổi)"
            echo "  2) Merge (giữ file cũ, thêm file mới)"
            echo "  3) Thay thế hoàn toàn"
            echo ""
            read -p "Chọn (1/2/3): " plans_choice

            case $plans_choice in
                2)
                    cp -rn "$plans_src/"* "$plans_dest/" 2>/dev/null || true
                    print_success "Merge plans/ hoàn tất"
                    ;;
                3)
                    rm -rf "$plans_dest"
                    cp -r "$plans_src" "$plans_dest"
                    print_success "Thay thế plans/ hoàn tất"
                    ;;
                *)
                    print_info "Giữ nguyên plans/ cũ"
                    ;;
            esac
        else
            mkdir -p "$plans_dest"
            cp -r "$plans_src/"* "$plans_dest/" 2>/dev/null || true
            print_success "Copy plans/ hoàn tất"
        fi
    else
        print_warning "Không tìm thấy thư mục plans/ trong source"
    fi
}

# Copy docs folder from ClaudeKit
copy_docs_folder() {
    print_info "Đang copy thư mục docs..."

    local docs_src="$PROJECT_ROOT/docs"
    local docs_dest="$CLAUDE_GLOBAL_DIR/docs"

    if [ -d "$docs_src" ]; then
        if [ "$MERGE_MODE" = true ] && [ -d "$docs_dest" ]; then
            print_warning "Thư mục docs/ đã tồn tại"
            echo ""
            echo "Bạn muốn làm gì với docs/?"
            echo "  1) Giữ folder cũ (không thay đổi)"
            echo "  2) Merge (giữ file cũ, thêm file mới)"
            echo "  3) Thay thế hoàn toàn"
            echo ""
            read -p "Chọn (1/2/3): " docs_choice

            case $docs_choice in
                2)
                    cp -rn "$docs_src/"* "$docs_dest/" 2>/dev/null || true
                    print_success "Merge docs/ hoàn tất"
                    ;;
                3)
                    rm -rf "$docs_dest"
                    cp -r "$docs_src" "$docs_dest"
                    print_success "Thay thế docs/ hoàn tất"
                    ;;
                *)
                    print_info "Giữ nguyên docs/ cũ"
                    ;;
            esac
        else
            mkdir -p "$docs_dest"
            cp -r "$docs_src/"* "$docs_dest/" 2>/dev/null || true
            print_success "Copy docs/ hoàn tất"
        fi
    else
        print_warning "Không tìm thấy thư mục docs/ trong source"
    fi
}

# Update paths in workflow files for global usage
update_workflow_paths() {
    print_info "Đang cập nhật paths trong workflow files..."

    # Files that need path updates for global usage
    # Only update references to ./.claude/workflows/ (global config)
    # Keep ./docs/ and ./plans/ as-is (project-specific)

    local files_to_update=(
        "$CLAUDE_GLOBAL_DIR/workflows/primary-workflow.md"
        "$CLAUDE_GLOBAL_DIR/commands/ask.md"
        "$CLAUDE_GLOBAL_DIR/commands/code/parallel.md"
        "$CLAUDE_GLOBAL_DIR/agents/code-reviewer.md"
        "$CLAUDE_GLOBAL_DIR/agents/fullstack-developer.md"
    )

    for file in "${files_to_update[@]}"; do
        if [ -f "$file" ]; then
            # Update ./.claude/workflows/ → ~/.claude/workflows/
            sed -i.bak 's|`\./\.claude/workflows/|`~/.claude/workflows/|g' "$file" 2>/dev/null || true
            sed -i.bak 's|"\./\.claude/workflows/|"~/.claude/workflows/|g' "$file" 2>/dev/null || true
            # Clean up backup files
            rm -f "$file.bak" 2>/dev/null || true
        fi
    done

    # Update api_key_helper.py to also check ~/.claude/.env
    local api_helper="$CLAUDE_GLOBAL_DIR/skills/common/api_key_helper.py"
    if [ -f "$api_helper" ]; then
        # Add ~/.claude/.env to the search paths
        sed -i.bak 's|# Step 3: Check \./\.claude/\.env|# Step 3: Check ~/.claude/.env (global)\n    global_claude_env = os.path.expanduser("~/.claude/.env")\n    if os.path.exists(global_claude_env):\n        load_dotenv(global_claude_env)\n        value = os.getenv(env_var)\n        if value:\n            return value\n\n    # Step 4: Check ./.claude/.env (project)|' "$api_helper" 2>/dev/null || true
        rm -f "$api_helper.bak" 2>/dev/null || true
    fi

    print_success "Cập nhật paths hoàn tất"
}

# Set permissions
set_permissions() {
    print_info "Đang thiết lập permissions..."

    # Make scripts executable
    find "$CLAUDE_GLOBAL_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$CLAUDE_GLOBAL_DIR" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    print_success "Thiết lập permissions hoàn tất"
}

# Copy _shared-rules.md to global .claude folder
copy_shared_rules() {
    print_info "Đang copy _shared-rules.md..."

    local shared_rules_src="$SCRIPT_DIR/_shared-rules.md"
    local shared_rules_dest="$CLAUDE_GLOBAL_DIR/_shared-rules.md"

    if [ -f "$shared_rules_src" ]; then
        if [ "$MERGE_MODE" = true ] && [ -f "$shared_rules_dest" ]; then
            print_warning "File _shared-rules.md đã tồn tại"
            echo ""
            echo "Bạn muốn làm gì với _shared-rules.md?"
            echo "  1) Giữ file cũ (không thay đổi)"
            echo "  2) Thay thế bằng file mới"
            echo ""
            read -p "Chọn (1/2): " shared_choice

            case $shared_choice in
                2)
                    cp "$shared_rules_src" "$shared_rules_dest"
                    print_success "Đã thay thế _shared-rules.md"
                    ;;
                *)
                    print_info "Giữ nguyên _shared-rules.md cũ"
                    ;;
            esac
        else
            cp "$shared_rules_src" "$shared_rules_dest"
            print_success "Copy _shared-rules.md hoàn tất"
        fi
    else
        print_warning "Không tìm thấy _shared-rules.md trong source"
    fi
}

# Inject shared rules to all agent files
inject_shared_rules() {
    print_info "Đang inject shared rules vào agent files..."

    local agents_dir="$CLAUDE_GLOBAL_DIR/agents"
    local shared_rules_ref="**CRITICAL:** You MUST read and strictly follow ALL rules at \`~/.claude/_shared-rules.md\` before proceeding. NON-NEGOTIABLE."
    local marker="<!-- SHARED_RULES_INJECTED -->"
    local old_pattern="Xem thêm.*_shared-rules.md"
    local injected=0
    local updated=0
    local skipped=0

    # Process each .md file in agents directory
    for file in "$agents_dir"/*.md; do
        local filename=$(basename "$file")

        # Skip the shared rules file itself
        if [[ "$filename" == "_shared-rules.md" ]]; then
            continue
        fi

        # Check if marker already exists
        if grep -q "$marker" "$file" 2>/dev/null; then
            # Check if old text exists and needs update
            if grep -qE "$old_pattern" "$file" 2>/dev/null; then
                # Remove old injected content (from marker to end of file)
                sed -i.bak "/$marker/,\$d" "$file" 2>/dev/null || true
                rm -f "$file.bak" 2>/dev/null || true

                # Re-inject with new text
                echo "" >> "$file"
                echo "$marker" >> "$file"
                echo "" >> "$file"
                echo "---" >> "$file"
                echo "" >> "$file"
                echo "$shared_rules_ref" >> "$file"
                ((updated++))
            else
                ((skipped++))
            fi
            continue
        fi

        # Append shared rules reference (new injection)
        echo "" >> "$file"
        echo "$marker" >> "$file"
        echo "" >> "$file"
        echo "---" >> "$file"
        echo "" >> "$file"
        echo "$shared_rules_ref" >> "$file"

        ((injected++))
    done

    print_success "Inject shared rules hoàn tất (new: $injected, updated: $updated, skipped: $skipped)"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              CÀI ĐẶT HOÀN TẤT!                               ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Cấu trúc đã cài đặt:${NC}"
    echo ""
    echo "  ~/.claude/"
    echo "  ├── CLAUDE.md          # Global instructions"
    echo "  ├── settings.json      # Security permissions (deny dangerous commands)"
    echo "  ├── _shared-rules.md   # Shared rules for all agents"
    echo "  ├── agents/            # AI agents"
    echo "  ├── commands/          # Slash commands"
    echo "  ├── skills/            # Skills"
    echo "  ├── workflows/         # Workflows"
    echo "  ├── hooks/             # Automation hooks"
    echo "  ├── plans/             # Plan templates"
    echo "  ├── docs/              # Documentation templates"
    echo "  └── scripts/           # Utility scripts"
    echo ""
    echo -e "${YELLOW}Cách sử dụng:${NC}"
    echo ""
    echo "  1. Mở terminal trong BẤT KỲ dự án nào"
    echo "  2. Chạy: claude"
    echo "  3. Sử dụng các commands:"
    echo ""
    echo "     /ck-help          - Xem hướng dẫn đầy đủ"
    echo "     /cook [task]      - Implement feature"
    echo "     /plan [task]      - Tạo kế hoạch"
    echo "     /fix [issue]      - Fix lỗi"
    echo "     /test             - Chạy tests"
    echo "     /bootstrap [desc] - Khởi tạo project mới"
    echo ""
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backup cũ được lưu tại:${NC} $BACKUP_DIR"
        echo ""
    fi
    echo -e "${BLUE}Để xem tất cả commands:${NC} ls ~/.claude/commands/"
    echo -e "${BLUE}Để xem tất cả skills:${NC} ls ~/.claude/skills/"
    echo ""
    echo -e "${YELLOW}Lưu ý quan trọng:${NC}"
    echo ""
    echo "  • ~/.claude/ chứa config GLOBAL (áp dụng tất cả projects)"
    echo "  • ./docs/ và ./plans/ vẫn là PROJECT-SPECIFIC (mỗi project riêng)"
    echo "  • Nếu project có .claude/ riêng → sẽ OVERRIDE global"
    echo ""
    echo -e "${BLUE}Đọc hướng dẫn đầy đủ:${NC}"
    echo "  cat $PROJECT_ROOT/CLAUDEKIT-GLOBAL-GUIDE.md"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    print_header

    # Find ClaudeKit Engineer folder
    PROJECT_ROOT=$(find_claudekit_root)
    if [ -z "$PROJECT_ROOT" ]; then
        print_error "Không tìm thấy folder claudekit-engineer*"
        print_error "Đảm bảo script nằm trong claudekit-engineer*/scripts/ hoặc cùng thư mục với claudekit-engineer*"
        exit 1
    fi

    print_info "Sử dụng ClaudeKit từ: $PROJECT_ROOT"
    echo ""

    # Check if source .claude folder exists
    if [ ! -d "$PROJECT_ROOT/.claude" ]; then
        print_error "Không tìm thấy thư mục .claude trong $PROJECT_ROOT"
        print_error "Folder ClaudeKit không hợp lệ"
        exit 1
    fi

    echo "Script này sẽ cài đặt ClaudeKit Engineer vào ~/.claude"
    echo "Sau khi cài đặt, bạn có thể sử dụng ClaudeKit trong TẤT CẢ dự án"
    echo ""
    read -p "Bạn có muốn tiếp tục? (y/n): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_warning "Hủy cài đặt"
        exit 0
    fi

    echo ""

    # Run installation steps
    backup_existing
    copy_claude_folder
    copy_plans_folder
    copy_docs_folder
    copy_settings_json
    copy_claude_md
    copy_shared_rules
    update_workflow_paths
    set_permissions
    inject_shared_rules
    print_summary
}

# Run main function
main "$@"
