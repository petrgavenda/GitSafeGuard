#!/bin/bash

# audit.sh - Audit repository for compliance
# Usage: ./audit.sh [options]
# Options:
#   -r, --report      Generate compliance report
#   -c, --check       Run compliance checks
#   -s, --scan        Scan all commits for issues
#   -n, --number N    Number of commits to audit (default: all)
#   -o, --output FILE Save report to file
#   -h, --help        Show this help message

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
GENERATE_REPORT=false
RUN_CHECKS=false
SCAN_COMMITS=false
NUM_COMMITS=""
OUTPUT_FILE=""

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
SecureGit - Repository Audit and Compliance

Usage: audit.sh [options]

Options:
  -r, --report      Generate compliance report
  -c, --check       Run compliance checks
  -s, --scan        Scan all commits for issues
  -n, --number N    Number of commits to audit (default: all)
  -o, --output FILE Save report to file
  -h, --help        Show this help message

Examples:
  ./audit.sh --report
  ./audit.sh --check
  ./audit.sh --scan --number 100
  ./audit.sh --report --output audit_report.txt
  ./audit.sh --check --scan

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--report)
                GENERATE_REPORT=true
                shift
                ;;
            -c|--check)
                RUN_CHECKS=true
                shift
                ;;
            -s|--scan)
                SCAN_COMMITS=true
                shift
                ;;
            -n|--number)
                NUM_COMMITS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
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
# Format Output
# ============================================================================
output_line() {
    local line="$1"
    echo "$line"
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$line" >> "$OUTPUT_FILE"
    fi
}

# ============================================================================
# Generate Compliance Report
# ============================================================================
generate_compliance_report() {
    log_info "Generating compliance report..."

    local total_commits
    local signed_commits
    local unsigned_commits
    local valid_commits
    local invalid_commits

    # Initialize output file
    if [[ -n "$OUTPUT_FILE" ]]; then
        > "$OUTPUT_FILE"
    fi

    # Header
    output_line ""
    output_line "================================"
    output_line "SecureGit Audit Report"
    output_line "$(date '+%Y-%m-%d %H:%M:%S')"
    output_line "================================"
    output_line ""

    # Repository Info
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    output_line "Repository: $repo_root"
    
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    output_line "Current Branch: $current_branch"
    output_line ""

    # Count commits
    total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    output_line "Total Commits: $total_commits"

    # Count signed commits
    signed_commits=$(git log --pretty=format:"%G?" ${NUM_COMMITS:+-n $NUM_COMMITS} 2>/dev/null | grep -c "G" || echo "0")
    valid_commits=$signed_commits

    # Calculate unsigned
    unsigned_commits=$((total_commits - signed_commits))
    output_line "Signed Commits: $signed_commits"
    output_line "Unsigned Commits: $unsigned_commits"

    # Calculate percentage
    if [[ $total_commits -gt 0 ]]; then
        local percentage=$((signed_commits * 100 / total_commits))
        output_line "Compliance Rate: $percentage%"
    fi

    output_line ""
    output_line "Signature Summary:"
    output_line "  Valid (G): $valid_commits"
    
    # Check for bad signatures
    local bad_count
    bad_count=$(git log --pretty=format:"%G?" ${NUM_COMMITS:+-n $NUM_COMMITS} 2>/dev/null | grep -c "B" || echo "0")
    if [[ $bad_count -gt 0 ]]; then
        output_line "  Bad (B): $bad_count"
    fi

    # Check for untrusted signatures
    local untrusted_count
    untrusted_count=$(git log --pretty=format:"%G?" ${NUM_COMMITS:+-n $NUM_COMMITS} 2>/dev/null | grep -c "U" || echo "0")
    if [[ $untrusted_count -gt 0 ]]; then
        output_line "  Untrusted (U): $untrusted_count"
    fi

    output_line ""

    if [[ -n "$OUTPUT_FILE" ]]; then
        log_info "Report saved to: $OUTPUT_FILE"
    fi

    return 0
}

# ============================================================================
# Run Compliance Checks
# ============================================================================
run_compliance_checks() {
    log_info "Running compliance checks..."

    local checks_passed=0
    local checks_failed=0

    if [[ -n "$OUTPUT_FILE" ]]; then
        > "$OUTPUT_FILE"
    fi

    output_line ""
    output_line "================================"
    output_line "SecureGit Compliance Checks"
    output_line "$(date '+%Y-%m-%d %H:%M:%S')"
    output_line "================================"
    output_line ""

    # Check 1: Repository is initialized
    output_line "[CHECK] Git repository initialized..."
    if is_git_repo; then
        output_line "  ✓ PASS: Repository is valid"
        ((checks_passed++))
    else
        output_line "  ✗ FAIL: Not a valid git repository"
        ((checks_failed++))
    fi

    # Check 2: User configured
    output_line ""
    output_line "[CHECK] Git user configured..."
    local user_name
    user_name=$(git config user.name 2>/dev/null || echo "")
    if [[ -n "$user_name" ]]; then
        output_line "  ✓ PASS: User name configured: $user_name"
        ((checks_passed++))
    else
        output_line "  ✗ FAIL: User name not configured"
        ((checks_failed++))
    fi

    # Check 3: GPG signing configured
    output_line ""
    output_line "[CHECK] GPG signing configured..."
    local gpg_config
    gpg_config=$(git config commit.gpgSign 2>/dev/null || echo "")
    if [[ "$gpg_config" == "true" ]]; then
        output_line "  ✓ PASS: GPG signing enabled"
        ((checks_passed++))
    else
        output_line "  ✗ FAIL: GPG signing not configured"
        ((checks_failed++))
    fi

    # Check 4: SecureGit configuration file exists
    output_line ""
    output_line "[CHECK] SecureGit configuration..."
    if [[ -f ".securegit-config" ]]; then
        output_line "  ✓ PASS: SecureGit configuration found"
        ((checks_passed++))
    else
        output_line "  ⚠ WARN: SecureGit configuration not found"
    fi

    # Check 5: Authorized authors file exists
    output_line ""
    output_line "[CHECK] Authorized authors file..."
    if [[ -f ".authorized-authors" ]]; then
        output_line "  ✓ PASS: Authorized authors file found"
        ((checks_passed++))
    else
        output_line "  ⚠ WARN: Authorized authors file not found"
    fi

    # Summary
    output_line ""
    output_line "================================"
    output_line "Check Summary:"
    output_line "  Passed: $checks_passed"
    output_line "  Failed: $checks_failed"
    output_line "================================"
    output_line ""

    if [[ -n "$OUTPUT_FILE" ]]; then
        log_info "Results saved to: $OUTPUT_FILE"
    fi

    if [[ $checks_failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Scan All Commits
# ============================================================================
scan_all_commits() {
    log_info "Scanning all commits for compliance issues..."

    if [[ -n "$OUTPUT_FILE" ]]; then
        > "$OUTPUT_FILE"
    fi

    output_line ""
    output_line "================================"
    output_line "SecureGit Commit Scan"
    output_line "$(date '+%Y-%m-%d %H:%M:%S')"
    output_line "================================"
    output_line ""

    find_unsigned_commits "HEAD" "$NUM_COMMITS" || return 1

    output_line ""
    if [[ -n "$OUTPUT_FILE" ]]; then
        log_info "Scan results saved to: $OUTPUT_FILE"
    fi

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

    # If no action specified, show help
    if ! $GENERATE_REPORT && ! $RUN_CHECKS && ! $SCAN_COMMITS; then
        # Default: run all checks
        RUN_CHECKS=true
        GENERATE_REPORT=true
    fi

    local failed=0

    if $GENERATE_REPORT; then
        if ! generate_compliance_report; then
            failed=1
        fi
    fi

    if $RUN_CHECKS; then
        if ! run_compliance_checks; then
            failed=1
        fi
    fi

    if $SCAN_COMMITS; then
        if ! scan_all_commits; then
            failed=1
        fi
    fi

    exit $failed
}

main "$@"
