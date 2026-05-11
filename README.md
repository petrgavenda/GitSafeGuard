# GitSafeGuard

CLI for GPG-signed Git workflows: init, key management, signed commits, verification, audits.

## Requirements

- git 2.x
- gpg 2.x
- bash (Git Bash or WSL on Windows)
- python or jq (optional, for config parsing)

## Install

```bash
chmod +x GitSafeGuard commands/*.sh lib/*.sh hooks/*
```

## Usage

```bash
./GitSafeGuard init --path .
./GitSafeGuard add-key --list
./GitSafeGuard add-key --generate
./GitSafeGuard add-key --configure KEY_ID
./GitSafeGuard add-key --export KEY_ID --output my-key.pub
./GitSafeGuard commit --message "feat: add secure commit flow" --all
./GitSafeGuard verify --commit HEAD
./GitSafeGuard verify --branch main
./GitSafeGuard verify --unsigned
./GitSafeGuard audit --report
./GitSafeGuard audit --check
./GitSafeGuard audit --scan --number 100
```

Use `./GitSafeGuard <command> --help` for full options.

## Configuration

- config/config.json is the default config file
- Set GITSAFEGUARD_CONFIG_FILE to override the config path
- init writes .gitsafeguard-config and .authorized-authors, installs hooks in .git/hooks
- git user.name and user.email are required for commits

## Layout

- GitSafeGuard (CLI entry)
- config/config.json (configuration)
- commands/ (command scripts)
- lib/ (shared modules)
- hooks/ (hook templates)