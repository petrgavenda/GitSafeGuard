#!/bin/bash

# log.sh - Logging utility for GitSafeGuard
# Description: Provides reusable logging functions with different severity levels
# Log file location: logs/gitsafeguard.log

# ============================================================================
# Configuration
# ============================================================================
LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/gitsafeguard.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR

# Log levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# ============================================================================
# _log_level_to_number()
# ============================================================================
# Description: Converts log level string to numeric value
# Arguments: $1 - Log level string (DEBUG, INFO, WARN, ERROR)
# Returns: 0 (success), prints numeric value
# ============================================================================
_log_level_to_number() {
    case "${1:-INFO}" in
        DEBUG) echo $LOG_DEBUG ;;
        INFO)  echo $LOG_INFO ;;
        WARN)  echo $LOG_WARN ;;
        ERROR) echo $LOG_ERROR ;;
        *)     echo $LOG_INFO ;;
    esac
}

# ============================================================================
# _should_log()
# ============================================================================
# Description: Determines if message should be logged based on log level
# Arguments: $1 - Message log level
# Returns: 0 if should log, 1 otherwise
# ============================================================================
_should_log() {
    local msg_level=$(_log_level_to_number "$1")
    local current_level=$(_log_level_to_number "$LOG_LEVEL")
    
    if [[ $msg_level -ge $current_level ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# _write_log()
# ============================================================================
# Description: Internal function to write log message with timestamp
# Arguments:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR)
#   $2 - Message
# Returns: 0 on success, 1 on error
# ============================================================================
_write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    
    # Skip if log level doesn't warrant logging
    if ! _should_log "$level"; then
        return 0
    fi

    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "Error: Cannot create log directory '$LOG_DIR'" >&2
            return 1
        }
    fi

    # Generate timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Format log message
    local formatted_msg="[$timestamp] [$level] $message"

    # Write to log file
    if echo "$formatted_msg" >> "$LOG_FILE" 2>/dev/null; then
        return 0
    else
        echo "Error: Cannot write to log file '$LOG_FILE'" >&2
        return 1
    fi
}

# ============================================================================
# log_debug()
# ============================================================================
# Description: Logs a debug message
# Arguments: $1 - Message, $2-N - Additional arguments (printf-style)
# Returns: 0 on success, 1 on error
# ============================================================================
log_debug() {
    local msg
    if [[ $# -gt 1 ]]; then
        msg=$(printf "$@")
    else
        msg="$1"
    fi
    _write_log "DEBUG" "$msg"
}

# ============================================================================
# log_info()
# ============================================================================
# Description: Logs an informational message
# Arguments: $1 - Message, $2-N - Additional arguments (printf-style)
# Returns: 0 on success, 1 on error
# ============================================================================
log_info() {
    local msg
    if [[ $# -gt 1 ]]; then
        msg=$(printf "$@")
    else
        msg="$1"
    fi
    _write_log "INFO" "$msg"
}

# ============================================================================
# log_warn()
# ============================================================================
# Description: Logs a warning message
# Arguments: $1 - Message, $2-N - Additional arguments (printf-style)
# Returns: 0 on success, 1 on error
# ============================================================================
log_warn() {
    local msg
    if [[ $# -gt 1 ]]; then
        msg=$(printf "$@")
    else
        msg="$1"
    fi
    _write_log "WARN" "$msg"
    echo "Warning: $msg" >&2
}

# ============================================================================
# log_error()
# ============================================================================
# Description: Logs an error message to both file and stderr
# Arguments: $1 - Message, $2-N - Additional arguments (printf-style)
# Returns: 0 on success, 1 on error
# ============================================================================
log_error() {
    local msg
    if [[ $# -gt 1 ]]; then
        msg=$(printf "$@")
    else
        msg="$1"
    fi
    _write_log "ERROR" "$msg"
    echo "Error: $msg" >&2
}

# ============================================================================
# log_clear()
# ============================================================================
# Description: Clears the log file
# Returns: 0 on success, 1 on error
# ============================================================================
log_clear() {
    if [[ -f "$LOG_FILE" ]]; then
        if > "$LOG_FILE" 2>/dev/null; then
            return 0
        else
            echo "Error: Cannot clear log file '$LOG_FILE'" >&2
            return 1
        fi
    fi
    return 0
}

# ============================================================================
# log_tail()
# ============================================================================
# Description: Displays the last N lines of the log file
# Arguments: $1 - Number of lines (optional, defaults to 20)
# Returns: 0 on success, 1 if log file doesn't exist
# ============================================================================
log_tail() {
    local num_lines="${1:-20}"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Log file does not exist: $LOG_FILE" >&2
        return 1
    fi

    tail -n "$num_lines" "$LOG_FILE"
    return 0
}

# ============================================================================
# log_get_file()
# ============================================================================
# Description: Returns the full path to the log file
# Returns: 0, prints log file path to stdout
# ============================================================================
log_get_file() {
    echo "$LOG_FILE"
    return 0
}

# ============================================================================
# End of log.sh
# ============================================================================
