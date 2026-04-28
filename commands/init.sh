#!/bin/bash

# init.sh - Initialize SecureGit in repository
# Usage: ./init.sh [options]
# Options:
#   -p, --path DIR       Repository path (default: current directory)
#   -g, --gpg-key KEY    GPG key ID to use
#   -e, --email EMAIL    Email for GPG key lookup
#   -h, --help           Show this help message

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
REPO_PATH="."
GPG_KEY=""
EMAIL=""

# Source library modules
source "$LIB_DIR/log.sh" || {
    echo "Error: Failed to load log.sh" >&2
    exit 1
}

source "$LIB_DIR/git_utils.sh" || {
    log_error "Failed to load git_utils.sh"
    exit 1
}

source "$LIB_DIR/gpg_utils.sh" || {
    log_error "Failed to load gpg_utils.sh"
    exit 1
}

# ============================================================================
# Usage/Help
# ============================================================================
show_help() {
    cat << 'EOF'
SecureGit - Initialize Secure Git Repository

Usage: init.sh [options]

Options:
  -p, --path DIR       Repository path (default: current directory)
  -g, --gpg-key KEY    GPG key ID to use
  -e, --email EMAIL    Email for GPG key lookup
  -h, --help           Show this help message

Examples:
  ./init.sh
  ./init.sh --path /my/repo --email user@example.com
  ./init.sh -g ABC123DEF456

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--path)
                REPO_PATH="$2"
                shift 2
                ;;
            -g|--gpg-key)
                GPG_KEY="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Initialize Repository
# ============================================================================
initialize_repository() {
    log_info "Starting SecureGit initialization..."

    # Change to repository directory
    cd "$REPO_PATH" || {
        log_error "Cannot change to directory: $REPO_PATH"
        return 1
    }

    # Initialize git repository if not already initialized
    if ! is_git_repo; then
        log_info "Initializing git repository..."
        if ! init_repo "."; then
            log_error "Failed to initialize git repository"
            return 1
        fi
    else
        log_info "Git repository already initialized"
    fi

    # Configure GPG signing
    log_info "Configuring GPG signing..."
    
    if [[ -n "$EMAIL" ]]; then
        log_debug "Looking up GPG key for email: $EMAIL"
        GPG_KEY=$(gpg_get_key_id "$EMAIL") || {
            log_error "Could not find GPG key for email: $EMAIL"
            return 1
        }
    fi

    if [[ -n "$GPG_KEY" ]]; then
        if ! gpg_configure_git "$GPG_KEY" "local"; then
            log_error "Failed to configure GPG signing"
            return 1
        fi
    else
        # Try to auto-detect GPG key
        log_info "No GPG key specified, attempting to auto-detect..."
        if ! gpg_configure_git "" "local"; then
            log_warn "Could not auto-detect or configure GPG key"
        fi
    fi

    # Create SecureGit config file
    if ! _create_securegit_config; then
        log_error "Failed to create SecureGit configuration"
        return 1
    fi

    # Install hooks
    if ! _install_hooks; then
        log_error "Failed to install git hooks"
        return 1
    fi

    # Create authorized authors file template
    if ! _create_authorized_authors_file; then
        log_warn "Failed to create authorized authors file"
    fi

    log_info "SecureGit initialization completed successfully!"
    return 0
}

# ============================================================================
# Create SecureGit Configuration
# ============================================================================
_create_securegit_config() {
    local config_file=".securegit-config"

    log_debug "Creating SecureGit configuration file..."

    if [[ -f "$config_file" ]]; then
        log_warn "Configuration file already exists: $config_file"
        return 0
    fi

    cat > "$config_file" << 'EOF'
# SecureGit Configuration

# Policy: Require GPG signatures on all commits
REQUIRE_GPG_SIGNATURE=true

# Policy: Validate commit messages conform to pattern
COMMIT_MESSAGE_PATTERN="^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{10,}"

# Policy: Authorized authors file path
AUTHORIZED_AUTHORS_FILE=".authorized-authors"

# GPG: Trust model (always/auto/ask)
GPG_TRUST_MODEL=always

# Hooks: Enable pre-commit hook
ENABLE_PRE_COMMIT_HOOK=true

# Hooks: Enable pre-push hook
ENABLE_PRE_PUSH_HOOK=true

# Logging: Log level (DEBUG/INFO/WARN/ERROR)
LOG_LEVEL=INFO
EOF

    log_info "Configuration file created: $config_file"
    return 0
}

# ============================================================================
# Install Git Hooks
# ============================================================================
_install_hooks() {
    local hooks_dir=".git/hooks"
    local project_hooks_dir="hooks"

    log_debug "Installing git hooks..."

    if [[ ! -d "$hooks_dir" ]]; then
        log_warn "Git hooks directory not found: $hooks_dir"
        return 1
    fi

    # Install pre-commit hook
    if [[ -f "$project_hooks_dir/pre-commit" ]]; then
        if cp "$project_hooks_dir/pre-commit" "$hooks_dir/pre-commit" && \
           chmod +x "$hooks_dir/pre-commit"; then
            log_info "Pre-commit hook installed"
        else
            log_error "Failed to install pre-commit hook"
            return 1
        fi
    fi

    # Install pre-push hook
    if [[ -f "$project_hooks_dir/pre-push" ]]; then
        if cp "$project_hooks_dir/pre-push" "$hooks_dir/pre-push" && \
           chmod +x "$hooks_dir/pre-push"; then
            log_info "Pre-push hook installed"
        else
            log_error "Failed to install pre-push hook"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Create Authorized Authors File
# ============================================================================
_create_authorized_authors_file() {
    local authors_file=".authorized-authors"

    log_debug "Creating authorized authors file..."

    if [[ -f "$authors_file" ]]; then
        log_warn "Authorized authors file already exists: $authors_file"
        return 0
    fi

    local user_email
    user_email=$(git config user.email)

    if [[ -n "$user_email" ]]; then
        echo "$user_email" > "$authors_file"
        log_info "Authorized authors file created with current user: $user_email"
        return 0
    else
        log_warn "Cannot determine git user email"
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    parse_arguments "$@"
    
    if ! initialize_repository; then
        log_error "Initialization failed"
        exit 1
    fi

    exit 0
}

main "$@"
