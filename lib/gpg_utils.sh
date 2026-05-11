#!/bin/bash

# gpg_utils.sh - GPG utility functions for GitSafeGuard
# Description: Provides functions to manage GPG keys and sign commits
# Dependencies: gpg, git, log.sh

# Source log utility if not already sourced
if ! declare -f log_info > /dev/null; then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log.sh"
fi

# Check if gpg is installed
if ! command -v gpg &> /dev/null; then
    log_error "GPG is not installed or not in PATH"
    return 1 2>/dev/null || exit 1
fi

# ============================================================================
# gpg_list_keys()
# ============================================================================
# Description: Lists all available GPG secret keys
# Arguments: None
# Returns: 0 on success, 1 on error
# Output: Prints key IDs and UIDs to stdout
# ============================================================================
gpg_list_keys() {
    log_debug "Listing GPG keys"
    
    local output
    output=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo "$output"
        return 0
    else
        log_error "Failed to list GPG keys"
        return 1
    fi
}

# ============================================================================
# gpg_get_key_id()
# ============================================================================
# Description: Gets the GPG key ID for a given email address
# Arguments: $1 - Email address
# Returns: 0 on success, 1 if not found or error
# Output: Prints key ID to stdout
# ============================================================================
gpg_get_key_id() {
    local email="$1"

    if [[ -z "$email" ]]; then
        log_error "Email address is required"
        return 1
    fi

    log_debug "Getting GPG key ID for email: $email"

    local key_id
    key_id=$(gpg --list-secret-keys "$email" --keyid-format LONG 2>/dev/null | grep -E "^\s*[A-F0-9]+" | head -1 | awk '{print $1}')

    if [[ -n "$key_id" ]]; then
        echo "$key_id"
        log_debug "Found GPG key: $key_id"
        return 0
    else
        log_error "GPG key not found for email: $email"
        return 1
    fi
}

# ============================================================================
# gpg_configure_git()
# ============================================================================
# Description: Configures git to use a specific GPG key for signing
# Arguments:
#   $1 - GPG key ID (optional, uses first available if not specified)
#   $2 - Scope: 'local' or 'global' (optional, defaults to 'local')
# Returns: 0 on success, 1 on error
# ============================================================================
gpg_configure_git() {
    local key_id="$1"
    local scope="${2:-local}"

    # Validate scope
    if [[ "$scope" != "local" && "$scope" != "global" ]]; then
        log_error "Invalid scope: $scope (must be 'local' or 'global')"
        return 1
    fi

    # If no key ID provided, use first available
    if [[ -z "$key_id" ]]; then
        key_id=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -E "^\s*[A-F0-9]+" | head -1 | awk '{print $1}')
        
        if [[ -z "$key_id" ]]; then
            log_error "No GPG keys found"
            return 1
        fi
    fi

    log_info "Configuring git to use GPG key: $key_id ($scope)"

    local config_arg="--${scope}"
    
    # Configure git signing
    if git config "$config_arg" user.signingkey "$key_id" && \
       git config "$config_arg" commit.gpgSign true && \
       git config "$config_arg" tag.gpgSign true; then
        log_info "Git configured successfully for GPG signing with key: $key_id"
        return 0
    else
        log_error "Failed to configure git GPG settings"
        return 1
    fi
}

# ============================================================================
# gpg_sign_commit()
# ============================================================================
# Description: Signs a specific commit with GPG
# Arguments:
#   $1 - Commit hash (optional, defaults to HEAD)
#   $2 - GPG key ID (optional, uses configured key if not specified)
# Returns: 0 on success, 1 on error
# ============================================================================
gpg_sign_commit() {
    local commit="${1:-HEAD}"
    local key_id="$2"

    log_debug "Attempting to sign commit: $commit"

    # Validate commit exists
    if ! git rev-parse "$commit" > /dev/null 2>&1; then
        log_error "Invalid commit: $commit"
        return 1
    fi

    # Build gpg-sign command as an array to prevent quoting issues
    local gpg_cmd=(git commit --amend --no-edit)
    
    if [[ -n "$key_id" ]]; then
        gpg_cmd+=(--gpg-sign="$key_id")
    else
        gpg_cmd+=(-S)
    fi

    if "${gpg_cmd[@]}" 2>/dev/null; then
        log_info "Commit signed successfully: $commit"
        return 0
    else
        log_error "Failed to sign commit: $commit"
        return 1
    fi
}

# ============================================================================
# gpg_verify_signature()
# ============================================================================
# Description: Verifies the GPG signature of a commit
# Arguments: $1 - Commit hash (optional, defaults to HEAD)
# Returns: 0 if valid signature, 1 otherwise
# Output: Prints signature details to stdout
# ============================================================================
gpg_verify_signature() {
    local commit="${1:-HEAD}"

    log_debug "Verifying GPG signature for commit: $commit"

    # Get commit signature
    local signature_info
    signature_info=$(git show --pretty=fuller "$commit" 2>/dev/null | grep -A 1 "gpgverify" || git show --verify "$commit" 2>&1)

    # Alternative: Use git log to check signature
    local is_signed
    is_signed=$(git log -1 --pretty=format:"%G?" "$commit" 2>/dev/null)

    case "$is_signed" in
        G)  # Good signature
            log_info "Valid GPG signature found for commit: $commit"
            git show --pretty=fuller "$commit" | grep -E "^(commit|Author|Date|gpgverify)"
            return 0
            ;;
        B)  # Bad signature
            log_error "Bad GPG signature for commit: $commit"
            return 1
            ;;
        U)  # Untrusted signature
            log_warn "Untrusted GPG signature for commit: $commit"
            return 1
            ;;
        X)  # Expired signature
            log_warn "Expired GPG signature for commit: $commit"
            return 1
            ;;
        N)  # No signature
            log_error "No GPG signature found for commit: $commit"
            return 1
            ;;
        *)
            log_error "Unknown signature status for commit: $commit"
            return 1
            ;;
    esac
}

# ============================================================================
# gpg_create_key()
# ============================================================================
# Description: Creates a new GPG key (interactive)
# Arguments: None
# Returns: 0 on success, 1 on error
# ============================================================================
gpg_create_key() {
    log_info "Starting interactive GPG key creation..."
    
    if gpg --full-generate-key; then
        log_info "GPG key created successfully"
        return 0
    else
        log_error "Failed to create GPG key"
        return 1
    fi
}

# ============================================================================
# gpg_trust_key()
# ============================================================================
# Description: Marks a GPG key as trusted
# Arguments: $1 - Key ID
# Returns: 0 on success, 1 on error
# ============================================================================
gpg_trust_key() {
    local key_id="$1"

    if [[ -z "$key_id" ]]; then
        log_error "Key ID is required"
        return 1
    fi

    log_info "Trusting GPG key: $key_id"

    # Note: This requires user interaction to set trust level
    if echo -e "trust\n5\ny" | gpg --command-fd 0 --edit-key "$key_id" > /dev/null 2>&1; then
        log_info "Key marked as trusted: $key_id"
        return 0
    else
        log_warn "Could not automatically trust key, may require manual setup"
        return 1
    fi
}

# ============================================================================
# gpg_export_public_key()
# ============================================================================
# Description: Exports the public key for a given key ID
# Arguments:
#   $1 - Key ID
#   $2 - Output file (optional, prints to stdout if not specified)
# Returns: 0 on success, 1 on error
# ============================================================================
gpg_export_public_key() {
    local key_id="$1"
    local output_file="$2"

    if [[ -z "$key_id" ]]; then
        log_error "Key ID is required"
        return 1
    fi

    log_debug "Exporting public key: $key_id"

    if [[ -n "$output_file" ]]; then
        if gpg --armor --export "$key_id" > "$output_file" 2>/dev/null; then
            log_info "Public key exported to: $output_file"
            return 0
        else
            log_error "Failed to export public key to: $output_file"
            return 1
        fi
    else
        if gpg --armor --export "$key_id" 2>/dev/null; then
            return 0
        else
            log_error "Failed to export public key: $key_id"
            return 1
        fi
    fi
}

# ============================================================================
# End of gpg_utils.sh
# ============================================================================
