#!/bin/bash

# verify.sh - Commit verification module for SecureGit
# Description: Verifies commit authenticity by checking signatures and policies
# Dependencies: git_utils.sh, gpg_utils.sh, log.sh

# Source dependencies if not already sourced
if ! declare -f is_git_repo > /dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git_utils.sh"
fi

if ! declare -f gpg_verify_signature > /dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gpg_utils.sh"
fi

if ! declare -f log_info > /dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log.sh"
fi

# ============================================================================
# verify_commit_signature()
# ============================================================================
# Description: Verifies a commit has a valid GPG signature
# Arguments: $1 - Commit hash (optional, defaults to HEAD)
# Returns: 0 if valid signature, 1 otherwise
# Output: Prints verification details to stdout
# ============================================================================
verify_commit_signature() {
    local commit="${1:-HEAD}"

    # Validate we're in a git repository
    if ! is_git_repo; then
        log_error "Not in a git repository"
        return 1
    fi

    # Validate commit exists
    if ! git rev-parse "$commit" > /dev/null 2>&1; then
        log_error "Invalid commit: $commit"
        return 1
    fi

    log_debug "Verifying commit signature: $commit"

    # Check GPG signature status
    local sig_status
    sig_status=$(git log -1 --pretty=format:"%G?" "$commit" 2>/dev/null)

    case "$sig_status" in
        G)
            log_info "Valid GPG signature verified for commit: $commit"
            _print_commit_details "$commit"
            return 0
            ;;
        B)
            log_error "Bad signature for commit: $commit"
            _print_commit_details "$commit"
            return 1
            ;;
        U)
            log_warn "Untrusted signature for commit: $commit"
            _print_commit_details "$commit"
            return 1
            ;;
        X)
            log_warn "Expired signature for commit: $commit"
            _print_commit_details "$commit"
            return 1
            ;;
        N)
            log_error "No signature found for commit: $commit"
            _print_commit_details "$commit"
            return 1
            ;;
        *)
            log_error "Unknown signature status for commit: $commit"
            return 1
            ;;
    esac
}

# ============================================================================
# verify_commit_policy()
# ============================================================================
# Description: Verifies a commit follows SecureGit policies
# Arguments:
#   $1 - Commit hash (optional, defaults to HEAD)
#   $2 - Policy file path (optional)
# Returns: 0 if compliant, 1 otherwise
# ============================================================================
verify_commit_policy() {
    local commit="${1:-HEAD}"
    local policy_file="${2:-.securegit-policy}"

    log_debug "Verifying commit policy: $commit"

    # Check required policies
    local passed=0

    # Policy 1: Must have GPG signature
    if verify_commit_signature "$commit" > /dev/null 2>&1; then
        log_info "Policy check passed: Commit is GPG signed"
        ((passed++))
    else
        log_error "Policy check failed: Commit not properly signed"
        return 1
    fi

    # Policy 2: Must have committer email
    local committer_email
    committer_email=$(git log -1 --pretty=format:"%ae" "$commit" 2>/dev/null)
    if [[ -n "$committer_email" ]]; then
        log_info "Policy check passed: Committer email present ($committer_email)"
        ((passed++))
    else
        log_error "Policy check failed: No committer email found"
        return 1
    fi

    # Policy 3: Commit message must not be empty
    local message
    message=$(git log -1 --pretty=format:"%s" "$commit" 2>/dev/null)
    if [[ -n "$message" ]]; then
        log_info "Policy check passed: Commit message present"
        ((passed++))
    else
        log_error "Policy check failed: Empty commit message"
        return 1
    fi

    log_info "All policy checks passed for commit: $commit"
    return 0
}

# ============================================================================
# verify_branch_history()
# ============================================================================
# Description: Verifies all commits on a branch have valid signatures
# Arguments:
#   $1 - Branch name (optional, defaults to current branch)
#   $2 - Number of commits to check (optional, defaults to all)
# Returns: 0 if all valid, 1 if any invalid
# Output: Prints verification summary to stdout
# ============================================================================
verify_branch_history() {
    local branch="${1:-.}"
    local num_commits="${2}"

    # Validate we're in a git repository
    if ! is_git_repo; then
        log_error "Not in a git repository"
        return 1
    fi

    log_info "Verifying branch history: $branch"

    local all_valid=true
    local checked=0

    # Get commits to check using an array
    local log_cmd=(git log --pretty=format:%H)
    
    if [[ -n "$num_commits" ]]; then
        log_cmd+=(-n "$num_commits")
    fi

    log_cmd+=("$branch")

    # Check each commit
    while read -r commit; do
        if ! verify_commit_signature "$commit" > /dev/null 2>&1; then
            all_valid=false
            log_error "Invalid signature on commit: $commit"
        fi
        ((checked++))
    done < <("${log_cmd[@]}")

    if [[ $checked -eq 0 ]]; then
        log_error "No commits found on branch: $branch"
        return 1
    fi

    echo "Verified $checked commit(s) on branch: $branch"

    if $all_valid; then
        log_info "All commits have valid signatures"
        return 0
    else
        log_error "Some commits have invalid signatures"
        return 1
    fi
}

# ============================================================================
# verify_author()
# ============================================================================
# Description: Verifies a commit was created by an authorized author
# Arguments:
#   $1 - Commit hash (optional, defaults to HEAD)
#   $2 - Authorized authors file (optional)
# Returns: 0 if authorized, 1 otherwise
# ============================================================================
verify_author() {
    local commit="${1:-HEAD}"
    local authors_file="${2:-.authorized-authors}"

    log_debug "Verifying commit author: $commit"

    # Get commit author
    local author_email
    author_email=$(git log -1 --pretty=format:"%ae" "$commit" 2>/dev/null)

    if [[ -z "$author_email" ]]; then
        log_error "Could not determine author for commit: $commit"
        return 1
    fi

    # If authors file exists, check against it
    if [[ -f "$authors_file" ]]; then
        if grep -q "^$author_email$" "$authors_file"; then
            log_info "Author authorized: $author_email"
            return 0
        else
            log_error "Author not authorized: $author_email"
            return 1
        fi
    else
        # If no authors file, just log and pass
        log_info "No authorized authors file found, accepting all authors: $author_email"
        return 0
    fi
}

# ============================================================================
# verify_merge_signature()
# ============================================================================
# Description: Verifies a merge commit has valid signatures from both parents
# Arguments: $1 - Merge commit hash (optional, defaults to HEAD)
# Returns: 0 if both parents valid, 1 otherwise
# Output: Prints verification details
# ============================================================================
verify_merge_signature() {
    local commit="${1:-HEAD}"

    log_debug "Verifying merge commit signatures: $commit"

    # Check if commit is a merge commit
    local parents
    parents=$(git rev-list --parents -n 1 "$commit" 2>/dev/null | awk '{print NF-1}')

    if [[ $parents -lt 2 ]]; then
        log_warn "Commit is not a merge commit: $commit"
        return 1
    fi

    # Verify the merge commit itself
    if ! verify_commit_signature "$commit" > /dev/null 2>&1; then
        log_error "Merge commit has invalid signature: $commit"
        return 1
    fi

    log_info "Merge commit signatures verified: $commit"
    return 0
}

# ============================================================================
# verify_unsigned_commits()
# ============================================================================
# Description: Finds and reports unsigned commits in a branch
# Arguments:
#   $1 - Branch name (optional, defaults to current branch)
#   $2 - Number of commits to check (optional, defaults to all)
# Returns: 0 if all signed, 1 if any unsigned found
# Output: Prints list of unsigned commits
# ============================================================================
verify_unsigned_commits() {
    local branch="${1:-.}"
    local num_commits="${2}"

    log_info "Checking for unsigned commits on branch: $branch"

    local unsigned_count=0
    local total=0

    local log_cmd=(git log --pretty=format:%H:%ae:%s)
    
    if [[ -n "$num_commits" ]]; then
        log_cmd+=(-n "$num_commits")
    fi

    log_cmd+=("$branch")

    echo "Scanning commits for signatures..."

    while IFS=: read -r commit author subject; do
        ((total++))
        local sig_status
        sig_status=$(git log -1 --pretty=format:"%G?" "$commit" 2>/dev/null)

        if [[ "$sig_status" == "N" ]]; then
            ((unsigned_count++))
            echo "  [UNSIGNED] $commit - $author - $subject"
            log_warn "Unsigned commit: $commit"
        fi
    done < <("${log_cmd[@]}" 2>/dev/null)

    echo ""
    echo "Results: $total commits checked, $unsigned_count unsigned"

    if [[ $unsigned_count -eq 0 ]]; then
        log_info "All commits are signed"
        return 0
    else
        log_error "Found $unsigned_count unsigned commit(s)"
        return 1
    fi
}

# ============================================================================
# Internal Helper Functions
# ============================================================================

# ============================================================================
# _print_commit_details()
# ============================================================================
# Description: Prints formatted commit details
# Arguments: $1 - Commit hash
# ============================================================================
_print_commit_details() {
    local commit="$1"
    
    echo ""
    echo "Commit Details:"
    git show --pretty=fuller --no-patch "$commit" 2>/dev/null | grep -E "^(commit|Author|Date|Signer)"
    echo ""
}

# ============================================================================
# End of verify.sh
# ============================================================================
