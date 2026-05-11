#!/bin/bash

# config.sh - Configuration loader for GitSafeGuard
# Reads config/config.json and exposes settings as variables.

_gsg_root_dir() {
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${lib_dir}/.." && pwd
}

_gsg_default_config_file() {
    local root_dir
    root_dir="$(_gsg_root_dir)"
    echo "${root_dir}/config/config.json"
}

_gsg_config_tool() {
    if command -v python3 > /dev/null 2>&1; then
        echo "python3"
        return 0
    fi

    if command -v python > /dev/null 2>&1; then
        echo "python"
        return 0
    fi

    if command -v jq > /dev/null 2>&1; then
        echo "jq"
        return 0
    fi

    return 1
}

_gsg_config_query() {
    local file="$1"
    local path="$2"
    local tool

    tool="$(_gsg_config_tool)" || return 1

    case "$tool" in
        python3|python)
            "$tool" - "$file" "$path" << 'PY'
import json
import sys

file_path = sys.argv[1]
path = sys.argv[2]

with open(file_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for key in path.split("."):
    if isinstance(data, dict) and key in data:
        data = data[key]
    else:
        sys.exit(1)

if isinstance(data, bool):
    sys.stdout.write("true" if data else "false")
elif data is None:
    sys.exit(1)
else:
    sys.stdout.write(str(data))
PY
            ;;
        jq)
            jq -r ".${path} // empty" "$file"
            ;;
        *)
            return 1
            ;;
    esac
}

gsg_config_get() {
    local path="$1"
    local default_value="${2-}"
    local value=""

    value="$(_gsg_config_query "$GSG_CONFIG_FILE" "$path" 2>/dev/null)" || value=""

    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

gsg_config_get_bool() {
    local path="$1"
    local default_value="${2-true}"
    local value

    value="$(gsg_config_get "$path" "$default_value")"

    case "${value,,}" in
        true|1|yes|y) echo "true" ;;
        false|0|no|n) echo "false" ;;
        *) echo "$default_value" ;;
    esac
}

gsg_make_abs() {
    local path="$1"

    if [[ -z "$path" ]]; then
        echo "$path"
        return 0
    fi

    if [[ "$path" =~ ^/ ]]; then
        echo "$path"
        return 0
    fi

    if [[ "$path" =~ ^[A-Za-z]: ]]; then
        echo "$path"
        return 0
    fi

    echo "${GSG_ROOT_DIR}/${path}"
}

gsg_load_config() {
    GSG_ROOT_DIR="$(_gsg_root_dir)"
    GSG_CONFIG_FILE="${GITSAFEGUARD_CONFIG_FILE:-$(_gsg_default_config_file)}"

    if [[ ! -f "$GSG_CONFIG_FILE" ]]; then
        return 0
    fi

    if ! _gsg_config_tool > /dev/null 2>&1; then
        echo "Warning: GitSafeGuard config found but no python or jq available. Using defaults." >&2
        return 0
    fi

    GSG_LOG_LEVEL="$(gsg_config_get "logging.level" "INFO")"
    GSG_LOG_FILE="$(gsg_make_abs "$(gsg_config_get "logging.logFile" "logs/gitsafeguard.log")")"

    LOG_LEVEL="$GSG_LOG_LEVEL"
    LOG_FILE="$GSG_LOG_FILE"
    LOG_DIR="$(dirname "$LOG_FILE")"

    GSG_COMMAND_INIT_ENABLED="$(gsg_config_get_bool "cli.commands.init.enabled" "true")"
    GSG_COMMAND_ADD_KEY_ENABLED="$(gsg_config_get_bool "cli.commands.addKey.enabled" "true")"
    GSG_COMMAND_COMMIT_ENABLED="$(gsg_config_get_bool "cli.commands.commit.enabled" "true")"
    GSG_COMMAND_VERIFY_ENABLED="$(gsg_config_get_bool "cli.commands.verify.enabled" "true")"
    GSG_COMMAND_AUDIT_ENABLED="$(gsg_config_get_bool "cli.commands.audit.enabled" "true")"

    local commit_policy_enabled
    local commit_cli_enabled

    commit_policy_enabled="$(gsg_config_get_bool "policies.commitMessage.enabled" "false")"
    commit_cli_enabled="$(gsg_config_get_bool "cli.commands.commit.validateMessage" "false")"

    if [[ "$commit_policy_enabled" == "true" || "$commit_cli_enabled" == "true" ]]; then
        GSG_COMMIT_VALIDATE_ENABLED="true"
    else
        GSG_COMMIT_VALIDATE_ENABLED="false"
    fi

    GSG_COMMIT_PATTERN="$(gsg_config_get "policies.commitMessage.pattern" "")"
    GSG_COMMIT_MIN_LENGTH="$(gsg_config_get "policies.commitMessage.minLength" "5")"
    GSG_COMMIT_MAX_LENGTH="$(gsg_config_get "policies.commitMessage.maxLength" "0")"

    GSG_VERIFY_DEFAULT_COMMIT="$(gsg_config_get "cli.commands.verify.defaultCommit" "HEAD")"

    GSG_DEFAULT_CONFIG_FILE="$(gsg_config_get "defaults.configFile" ".gitsafeguard-config")"
    GSG_DEFAULT_AUTHORS_FILE="$(gsg_config_get "defaults.authorizedAuthorsFile" ".authorized-authors")"
    GSG_DEFAULT_POLICY_FILE="$(gsg_config_get "defaults.policyFile" ".gitsafeguard-policy")"

    GSG_INIT_CREATE_CONFIG="$(gsg_config_get_bool "cli.commands.init.createConfig" "true")"
    GSG_INIT_INSTALL_HOOKS="$(gsg_config_get_bool "cli.commands.init.installHooks" "true")"
    GSG_INIT_CREATE_AUTHORS_FILE="$(gsg_config_get_bool "cli.commands.init.createAuthorsFile" "true")"
}

gsg_command_is_enabled() {
    local command="$1"
    local enabled="true"

    case "$command" in
        init)
            enabled="${GSG_COMMAND_INIT_ENABLED:-true}"
            ;;
        add-key)
            enabled="${GSG_COMMAND_ADD_KEY_ENABLED:-true}"
            ;;
        commit)
            enabled="${GSG_COMMAND_COMMIT_ENABLED:-true}"
            ;;
        verify)
            enabled="${GSG_COMMAND_VERIFY_ENABLED:-true}"
            ;;
        audit)
            enabled="${GSG_COMMAND_AUDIT_ENABLED:-true}"
            ;;
        *)
            enabled="true"
            ;;
    esac

    if [[ "$enabled" == "true" ]]; then
        return 0
    fi

    return 1
}

gsg_require_command_enabled() {
    local command="$1"

    if ! gsg_command_is_enabled "$command"; then
        echo "Error: Command '$command' is disabled by configuration ($GSG_CONFIG_FILE)" >&2
        return 1
    fi

    return 0
}
