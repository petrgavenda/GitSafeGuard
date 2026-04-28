#!/bin/bash

# commit.sh - Make secure signed commits
# Usage: ./commit.sh [options]
# Options:
#   -m, --message MSG    Commit message
#   -f, --file FILE      Read message from file
#   -a, --all            Stage all changes before committing
#   -k, --key KEY        GPG key to use (optional, uses configured key if not specified)
#   -h, --help           Show this help message

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
COMMIT_MESSAGE=""
MESSAGE_FILE=""
KEY=""
STAGE_ALL=false

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
SecureGit - Make Secure Signed Commits

Usage: commit.sh [options]

Options:
  -m, --message MSG    Commit message
  -f, --file FILE      Read message from file
  -a, --all            Stage all changes before committing
  -k, --key KEY        GPG key to use (optional)
  -h, --help           Show this help message

Examples:
  ./commit.sh --message "Add new feature"
  ./commit.sh -m "Fix bug" --all
  ./commit.sh -f commit-msg.txt
  ./commit.sh -m "Release v1.0" --key ABC123DEF456

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)
                COMMIT_MESSAGE="$2"
                shift 2
                ;;
            -f|--file)
                MESSAGE_FILE="$2"
                shift 2
                ;;
            -a|--all)
                STAGE_ALL=true
                shift
                ;;
            -k|--key)
                KEY="$2"
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
# Validate Environment
# ============================================================================
validate_environment() {
    log_debug "Validating environment..."

    # Check if in git repository
    if ! is_git_repo; then
        log_error "Not in a git repository"
        return 1
    fi

    # Check if git is configured with user name and email
    local user_name
    local user_email
    
    user_name=$(git config user.name 2>/dev/null || echo "")
    user_email=$(git config user.email 2>/dev/null || echo "")

    if [[ -z "$user_name" || -z "$user_email" ]]; then
        log_error "Git user not configured"
        echo "Configure git user with:"
        echo "  git config --global user.name 'Your Name'"
        echo "  git config --global user.email 'your.email@example.com'"
        return 1
    fi

    # Check if GPG signing is configured
    local gpg_sign_config
    gpg_sign_config=$(git config commit.gpgSign 2>/dev/null || echo "")

    if [[ "$gpg_sign_config" != "true" ]]; then
        log_warn "GPG signing not configured for this repository"
        echo "Consider running: init.sh to configure SecureGit"
    fi

    return 0
}

# ============================================================================
# Get Commit Message
# ============================================================================
get_commit_message() {
    if [[ -n "$COMMIT_MESSAGE" ]]; then
        echo "$COMMIT_MESSAGE"
        return 0
    fi

    if [[ -n "$MESSAGE_FILE" ]]; then
        if [[ ! -f "$MESSAGE_FILE" ]]; then
            log_error "Message file not found: $MESSAGE_FILE"
            return 1
        fi

        cat "$MESSAGE_FILE"
        return 0
    fi

    # No message provided, error out
    log_error "Commit message is required"
    show_help
    return 1
}

# ============================================================================
# Stage Changes
# ============================================================================
stage_changes() {
    log_debug "Staging changes..."

    # Check if there are any changes
    if ! git status --porcelain | grep -q .; then
        log_warn "No changes to stage"
        return 1
    fi

    if git add -A > /dev/null 2>&1; then
        log_info "All changes staged"
        return 0
    else
        log_error "Failed to stage changes"
        return 1
    fi
}

# ============================================================================
# Make Commit
# ============================================================================
make_commit() {
    local message
    message=$(get_commit_message) || {
        log_error "Failed to get commit message"
        return 1
    }

    if [[ -z "$message" ]]; then
        log_error "Commit message is empty"
        return 1
    fi

    log_debug "Message length: ${#message} characters"

    # Validate message is not too short
    if [[ ${#message} -lt 5 ]]; then
        log_error "Commit message too short (minimum 5 characters)"
        return 1
    fi

    # Stage changes if requested
    if $STAGE_ALL; then
        if ! stage_changes; then
            log_error "No changes to commit"
            return 1
        fi
    fi

    # Check if there are staged changes
    if ! git diff --cached --quiet; then
        # Changes are staged
        :
    else
        log_error "No staged changes to commit"
        echo "Use --all flag to stage changes, or stage them manually"
        return 1
    fi

    log_info "Creating signed commit..."

    # Build commit command as an array to handle spaces securely
    local commit_cmd=(git commit -S)
    
    if [[ -n "$KEY" ]]; then
        commit_cmd+=(--gpg-sign="$KEY")
    fi

    commit_cmd+=(-m "$message")

    # Execute commit
    if "${commit_cmd[@]}"; then
        log_info "Commit created successfully"
        
        # Show commit info
        echo ""
        echo "Commit created:"
        git log -1 --pretty=fuller
        echo ""
        
        return 0
    else
        log_error "Failed to create commit"
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    parse_arguments "$@"

    if ! validate_environment; then
        exit 1
    fi

    if ! make_commit; then
        exit 1
    fi

    exit 0
}

main "$@"
