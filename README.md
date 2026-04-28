# GitSafeGuard

GitSafeGuard is a small command-line tool for GPG-signed Git workflows, commit verification, and repository audits.

## Requirements

- `git`
- `gpg`
- `bash`

## Quick Start

Make the scripts executable if needed:

```bash
chmod +x GitSafeGuard commands/*.sh lib/*.sh
```

Initialize GitSafeGuard in a repository:

```bash
./GitSafeGuard init --path .
```

## Commands

### Add or manage GPG keys

```bash
./GitSafeGuard add-key --list
./GitSafeGuard add-key --generate
./GitSafeGuard add-key --configure KEY_ID
./GitSafeGuard add-key --export KEY_ID --output my-key.pub
```

### Create a signed commit

```bash
./GitSafeGuard commit --message "feat: add secure commit flow" --all
```

### Verify commits

```bash
./GitSafeGuard verify
./GitSafeGuard verify --commit HEAD
./GitSafeGuard verify --branch main
./GitSafeGuard verify --unsigned
```

### Audit a repository

```bash
./GitSafeGuard audit --report
./GitSafeGuard audit --check
./GitSafeGuard audit --scan --number 100
```

## Files

- `GitSafeGuard` - Main CLI entry script
- `config/config.json` - integrated configuration
- `lib/` - reusable bash modules
- `commands/` - CLI entry points
- `hooks/` - hook templates

## Notes

- The tool expects Git user identity to be configured.
- GitSafeGuard is designed to enforce signed commits and verify repository compliance.