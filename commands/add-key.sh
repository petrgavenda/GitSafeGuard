#!/bin/bash

# add-key.sh - Manage GPG keys for GitSafeGuard
# Usage: ./add-key.sh [options]
# Options:
#   -l, --list           List all available GPG keys
#   -g, --generate       Generate new GPG key (interactive)
#   -c, --configure KEY  Configure git to use specified key
#   -e, --email EMAIL    Email to use for key lookup/setup
#   -x, --export KEY     Export public key
#   -o, --output FILE    Output file for exported key
#   -h, --help           Show this help message

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"
COMMAND=""
GPG_KEY=""
EMAIL=""
OUTPUT_FILE=""

# Source library modules
source "$LIB_DIR/config.sh" || {
    echo "Error: Failed to load config.sh" >&2
    exit 1
}
gsg_load_config

source "$LIB_DIR/log.sh" || {
    echo "Error: Failed to load log.sh" >&2
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
GitSafeGuard - Manage GPG Keys

Usage: add-key.sh [options]

Commands:
  -l, --list           List all available GPG keys
  -g, --generate       Generate new GPG key (interactive)
  -c, --configure KEY  Configure git to use specified key
  -e, --email EMAIL    Email to use for key lookup/setup
  -x, --export KEY     Export public key
  -o, --output FILE    Output file for exported key
  -h, --help           Show this help message

Examples:
  ./add-key.sh --list
  ./add-key.sh --generate
  ./add-key.sh --configure ABC123DEF456
  ./add-key.sh --email user@example.com --configure
  ./add-key.sh --export ABC123DEF456 --output my-key.pub

EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================
require_arg() {
    local option="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        echo "Error: $option requires a value" >&2
        show_help
        exit 1
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)
                COMMAND="list"
                shift
                ;;
            -g|--generate)
                COMMAND="generate"
                shift
                ;;
            -c|--configure)
                COMMAND="configure"
                GPG_KEY="${2:-}"
                if [[ -z "$GPG_KEY" ]]; then
                    shift
                else
                    shift 2
                fi
                ;;
            -e|--email)
                require_arg "$1" "${2-}"
                EMAIL="$2"
                shift 2
                ;;
            -x|--export)
                require_arg "$1" "${2-}"
                COMMAND="export"
                GPG_KEY="$2"
                shift 2
                ;;
            -o|--output)
                require_arg "$1" "${2-}"
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
# List GPG Keys
# ============================================================================
list_keys() {
    log_info "Listing available GPG keys..."
    
    local output
    output=$(gpg_list_keys) || {
        log_error "Failed to list GPG keys"
        return 1
    }

    if [[ -z "$output" ]]; then
        log_warn "No GPG keys found"
        echo "No GPG keys found. Use 'add-key.sh --generate' to create one."
        return 1
    fi

    echo ""
    echo "Available GPG Keys:"
    echo "==================="
    echo "$output"
    echo ""

    return 0
}

# ============================================================================
# Generate New GPG Key
# ============================================================================
generate_key() {
    log_info "Starting GPG key generation..."
    echo ""
    echo "Follow the prompts to create a new GPG key."
    echo "This process is interactive and may take a few minutes."
    echo ""
    
    if ! gpg_create_key; then
        log_error "Failed to create GPG key"
        return 1
    fi

    log_info "GPG key created successfully"
    
    # Show newly created keys
    echo ""
    echo "Newly created keys:"
    list_keys

    return 0
}

# ============================================================================
# Configure Git to Use Key
# ============================================================================
configure_key() {
    local key_to_configure="$GPG_KEY"

    # If email provided, lookup key by email
    if [[ -n "$EMAIL" && -z "$key_to_configure" ]]; then
        log_debug "Looking up GPG key for email: $EMAIL"
        key_to_configure=$(gpg_get_key_id "$EMAIL") || {
            log_error "Could not find GPG key for email: $EMAIL"
            return 1
        }
    fi

    # If still no key, list available and let user know
    if [[ -z "$key_to_configure" ]]; then
        log_error "No GPG key specified"
        echo ""
        echo "Usage:"
        echo "  ./add-key.sh --configure KEY_ID"
        echo "  ./add-key.sh --email user@example.com --configure"
        echo ""
        echo "Available keys:"
        list_keys
        return 1
    fi

    log_info "Configuring git to use GPG key: $key_to_configure"
    
    if ! gpg_configure_git "$key_to_configure" "local"; then
        log_error "Failed to configure GPG key"
        return 1
    fi

    log_info "Git configured successfully"
    echo ""
    echo "Current git configuration:"
    git config --local --list | grep -E "(gpg|signing)" || true
    echo ""

    return 0
}

# ============================================================================
# Export Public Key
# ============================================================================
export_key() {
    if [[ -z "$GPG_KEY" ]]; then
        log_error "GPG key ID is required for export"
        return 1
    fi

    log_info "Exporting public key: $GPG_KEY"

    if [[ -n "$OUTPUT_FILE" ]]; then
        log_debug "Exporting to file: $OUTPUT_FILE"
        if ! gpg_export_public_key "$GPG_KEY" "$OUTPUT_FILE"; then
            log_error "Failed to export public key"
            return 1
        fi
        log_info "Public key exported to: $OUTPUT_FILE"
    else
        log_debug "Exporting to stdout"
        if ! gpg_export_public_key "$GPG_KEY"; then
            log_error "Failed to export public key"
            return 1
        fi
    fi

    return 0
}

# ============================================================================
# Main
# ============================================================================
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    parse_arguments "$@"

    if ! gsg_require_command_enabled "add-key"; then
        exit 1
    fi

    case "${COMMAND:-list}" in
        list)
            list_keys
            ;;
        generate)
            generate_key
            ;;
        configure)
            configure_key
            ;;
        export)
            export_key
            ;;
        *)
            echo "Unknown command: $COMMAND" >&2
            show_help
            exit 1
            ;;
    esac

    exit $?
}

main "$@"
