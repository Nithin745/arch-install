# Arch Install - Agent Guidelines

## Testing & Linting

- **Lint scripts**: `shellcheck *.sh` (install with `pacman -S shellcheck` if needed)
- **Test in VM**: Use VirtualBox/QEMU before production use
- **Dry run**: Review scripts with `bash -n script.sh` to check syntax

## Code Style

- **Language**: Bash shell scripts (#!/bin/bash)
- **Error handling**: Use `set -e` at start; use `error_exit()` for fatal errors
- **Logging**: Use `log_info()`, `log_warn()`, `log_error()`, `log_step()` functions consistently
- **Variables**: UPPERCASE for constants/config, lowercase for local vars; quote all variables: `"${VAR}"`
- **Conditionals**: Use `[[ ]]` for tests, not `[ ]`; check command success with `command &> /dev/null`
- **Functions**: Define at top of script after variables; use descriptive names
- **Comments**: Add headers to scripts and sections; explain non-obvious logic
- **Indentation**: 4 spaces (no tabs)
- **Line length**: Keep under 120 characters where practical

## Architecture

- **install.sh**: Base system installation (run as root from Arch ISO)
- **post-install.sh**: User-level setup, AUR helper (paru), packages (run as user after reboot)
- **config.sh**: Dotfiles management with GNU Stow + Git
- **install.conf.example**: Template for unattended installation config
- **packages.conf**: System package definitions
- **custom-packages.txt**: User's personal package list
