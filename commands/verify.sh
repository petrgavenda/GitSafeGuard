#!/bin/bash

# verify.sh - Verify commit signatures and compliance
# Usage: ./verify.sh [options]
# Options:
#   -c, --commit HASH    Verify specific commit (default: HEAD)
#   -b, --branch BRANCH  Verify all commits on branch
#   -p, --policy POLICY  Check commit against policy
#   -a, --all            Verify entire repository
#   -u, --unsigned       Find unsigned commits
#   -n, --number COUNT   Number of commits to check
#   -h, --help           Show this help message

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
COMMIT=""
BRANCH=""
CHECK_POLICY=false
VERIFY_ALL=false
FIND_UNSIGNED=false
NUM_COMMITS=""

# Source library modules
source "$LIB_DIR/log.sh" || {
    echo "Error: Failed to load log.sh" >&2
    exit 1
}

source "$LIB_DIR/git_utils.sh" || {
    log_error "Failed to load git_utils.sh"
    exit 1
}

source "$LIB_DIR/verify.sh" || {
    log_error "Failed to load verify.sh"
    exit 1
}

# ============================================================================
# Usage/Help
# ============================================================================
show_help() {
    cat << 'EOF'
SecureGit - Verify Commit Signatures

Usage: verify.sh [options]

Options:
  -c, --commit HASH    Verify specific commit (default: HEAD)
  -b, --branch BRANCH  Verify all commits on branch
  -p, --policy         Check commit against SecureGit policy
  -a, --all            Verify entire repository history
  -u, --unsigned       Find unsigned commits on branch
  -n, --number COUNT   Number of commits to check
  -h, --help           Show this help message

Examples:
  ./verify.sh
  ./verify.sh --commit abc123def
  ./verify.sh --branch develop --number 20
  ./verify.sh --all
  ./verify.sh --unsigned
  ./verify.sh --policy

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--commit)
                COMMIT="$2"
                shift 2
                ;;
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            -p|--policy)
                CHECK_POLICY=true
                shift
                ;;
            -a|--all)
                VERIFY_ALL=true
                shift
                ;;
            -u|--unsigned)
                FIND_UNSIGNED=true
                shift
                ;;
            -n|--number)
                NUM_COMMITS="$2"
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
# Verify Single Commit
# ============================================================================
verify_single_commit() {
    local commit="${1:-HEAD}"

    log_info "Verifying commit: $commit"
    echo ""

    if ! verify_commit_signature "$commit"; then
        return 1
    fi

    if $CHECK_POLICY; then
        echo ""
        log_info "Checking policy compliance..."
        if ! verify_commit_policy "$commit"; then
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Verify Branch History
# ============================================================================
verify_branch_history() {
    local branch="${1:-.}"
    local num_commits="$NUM_COMMITS"

    log_info "Verifying branch history: $branch"
    echo ""

    if ! verify_branch_history "$branch" "$num_commits"; then
        return 1
    fi

    return 0
}

# ============================================================================
# Verify All Repository Commits
# ============================================================================
verify_all_commits() {
    log_info "Verifying all commits in repository..."
    echo ""

    if ! verify_branch_history "HEAD" ""; then
        log_error "Some commits have invalid signatures"
        return 1
    fi

    return 0
}

# ============================================================================
# Find Unsigned Commits
# ============================================================================
find_unsigned_commits() {
    local branch="${1:-HEAD}"
    local num_commits="$NUM_COMMITS"

    log_info "Scanning for unsigned commits on branch: $branch"
    echo ""

    if ! verify_unsigned_commits "$branch" "$num_commits"; then
        return 1
    fi

    return 0
}

# ============================================================================
# Generate Verification Report
# ============================================================================
generate_report() {
    local total_commits
    local signed_commits
    local unsigned_commits

    log_info "Generating verification report..."
    echo ""
    echo "================================"
    echo "SecureGit Verification Report"
    echo "================================"
    echo ""

    # Count total commits
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    echo "Total commits: $total_commits"

    # Count signed commits
    signed_commits=$(git log --pretty=format:"%G?" | grep -c "G" || echo "0")
    echo "Signed commits: $signed_commits"
    
    # Calculate unsigned
    unsigned_commits=$((total_commits - signed_commits))
    echo "Unsigned commits: $unsigned_commits"

    # Calculate percentage
    if [[ $total_commits -gt 0 ]]; then
        local percentage=$((signed_commits * 100 / total_commits))
        echo "Compliance: $percentage%"
    else
        echo "Compliance: N/A (no commits)"
    fi

    echo ""
    return 0
}

# ============================================================================
# Main
# ============================================================================
main() {
    if ! is_git_repo; then
        log_error "Not in a git repository"
        exit 1
    fi

    parse_arguments "$@"

    # Default to verifying HEAD if no options specified
    if [[ -z "$COMMIT" && -z "$BRANCH" && "$VERIFY_ALL" == "false" && "$FIND_UNSIGNED" == "false" ]]; then
        COMMIT="HEAD"
    fi

    if $VERIFY_ALL; then
        verify_all_commits || exit 1
        generate_report
    elif $FIND_UNSIGNED; then
        find_unsigned_commits "${BRANCH:-HEAD}" || exit 1
    elif [[ -n "$BRANCH" ]]; then
        verify_branch_history "$BRANCH" || exit 1
    else
        verify_single_commit "$COMMIT" || exit 1
    fi

    exit 0
}

main "$@"
