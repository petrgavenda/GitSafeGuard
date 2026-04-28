# GitSafeGuard

SecureGit is a small command-line tool for GPG-signed Git workflows, commit verification, and repository audits.

## Requirements

- `git`
- `gpg`
- `bash`

## Quick Start

Make the scripts executable if needed:

```bash
chmod +x commands/*.sh lib/*.sh
```

Initialize SecureGit in a repository:

```bash
./commands/init.sh --path .
```

## Commands

### Add or manage GPG keys

```bash
./commands/add-key.sh --list
./commands/add-key.sh --generate
./commands/add-key.sh --configure KEY_ID
./commands/add-key.sh --export KEY_ID --output my-key.pub
```

### Create a signed commit

```bash
./commands/commit.sh --message "feat: add secure commit flow" --all
```

### Verify commits

```bash
./commands/verify.sh
./commands/verify.sh --commit HEAD
./commands/verify.sh --branch main
./commands/verify.sh --unsigned
```

### Audit a repository

```bash
./commands/audit.sh --report
./commands/audit.sh --check
./commands/audit.sh --scan --number 100
```

## Files

- `config/config.json` - integrated configuration
- `lib/` - reusable bash modules
- `commands/` - CLI entry points
- `hooks/` - hook templates

## Notes

- The tool expects Git user identity to be configured.
- SecureGit is designed to enforce signed commits and verify repository compliance.