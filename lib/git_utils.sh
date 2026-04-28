#!/bin/bash

# git_utils.sh - Git utility functions for CLI tools
# Description: Provides reusable functions to interact with git repositories
# Error handling: All functions return 1 on error, 0 on success

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed or not in PATH" >&2
    return 1 2>/dev/null || exit 1
fi

# ============================================================================
# is_git_repo()
# ============================================================================
# Description: Checks if the current directory is a git repository
# Arguments: None
# Returns: 0 if git repo, 1 otherwise
# ============================================================================
is_git_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# init_repo()
# ============================================================================
# Description: Initializes a new git repository in the specified directory
# Arguments: 
#   $1 - Directory path (optional, defaults to current directory)
# Returns: 0 on success, 1 on error
# Output: Prints initialization messages or error to stderr
# ============================================================================
init_repo() {
    local repo_path="${1:-.}"

    # Validate directory exists
    if [[ ! -d "$repo_path" ]]; then
        echo "Error: Directory '$repo_path' does not exist" >&2
        return 1
    fi

    # Check if already a git repo
    if is_git_repo; then
        echo "Error: '$repo_path' is already a git repository" >&2
        return 1
    fi

    # Initialize repository
    if git init "$repo_path" > /dev/null 2>&1; then
        echo "Repository initialized at '$repo_path'"
        return 0
    else
        echo "Error: Failed to initialize git repository at '$repo_path'" >&2
        return 1
    fi
}

# ============================================================================
# get_current_branch()
# ============================================================================
# Description: Gets the current branch name of the repository
# Arguments: None
# Returns: 0 on success, 1 on error
# Output: Prints branch name to stdout, errors to stderr
# ============================================================================
get_current_branch() {
    # Check if in a git repository
    if ! is_git_repo; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    local branch_name
    
    # Get the current branch name
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local exit_code=$?

    if [[ $exit_code -eq 0 && -n "$branch_name" ]]; then
        echo "$branch_name"
        return 0
    else
        echo "Error: Failed to get current branch" >&2
        return 1
    fi
}

# ============================================================================
# get_commit_history()
# ============================================================================
# Description: Gets commit history with optional formatting
# Arguments:
#   $1 - Number of commits to retrieve (optional, defaults to 10)
#   $2 - Format string (optional, defaults to "%h - %s (%an, %ar)")
#        Common formats:
#          %h   - abbreviated commit hash
#          %H   - full commit hash
#          %s   - subject
#          %an  - author name
#          %ae  - author email
#          %ar  - author date relative
#          %ai  - author date ISO
# Returns: 0 on success, 1 on error
# Output: Prints commit history to stdout, errors to stderr
# ============================================================================
get_commit_history() {
    local num_commits="${1:-10}"
    local format="${2:-%h - %s (%an, %ar)}"

    # Validate num_commits is a positive integer
    if ! [[ "$num_commits" =~ ^[0-9]+$ ]] || [[ $num_commits -lt 1 ]]; then
        echo "Error: Number of commits must be a positive integer" >&2
        return 1
    fi

    # Check if in a git repository
    if ! is_git_repo; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    # Get commit history
    if git log -n "$num_commits" --pretty=format:"$format" 2>/dev/null; then
        echo
        return 0
    else
        echo "Error: Failed to retrieve commit history" >&2
        return 1
    fi
}

# ============================================================================
# Helper Functions
# ============================================================================

# get_repo_root()
# Description: Gets the root directory of the git repository
# Returns: 0 on success, 1 on error
# Output: Prints root path to stdout
get_repo_root() {
    if ! is_git_repo; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    git rev-parse --show-toplevel 2>/dev/null
    return $?
}

# get_status()
# Description: Gets the current git status
# Returns: 0 on success, 1 on error
# Output: Prints status to stdout
get_status() {
    if ! is_git_repo; then
        echo "Error: Not a git repository" >&2
        return 1
    fi

    git status 2>/dev/null
    return $?
}

# ============================================================================
# End of git_utils.sh
# ============================================================================
