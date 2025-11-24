#!/bin/bash
# Configuration Management Script
# Manage dotfiles using GNU Stow with Git repository

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

error_exit() {
    log_error "$1"
    exit 1
}

# Configuration
DOTFILES_DIR="${HOME}/dotfiles"
BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d-%H%M%S)"

clear
echo "=========================================="
echo "  Dotfiles Management with Stow"
echo "=========================================="
echo ""
echo "Options:"
echo "1. Clone dotfiles repository"
echo "2. Deploy dotfiles (stow)"
echo "3. Remove deployed dotfiles (unstow)"
echo "4. Update dotfiles from remote"
echo "5. Re-stow all packages"
echo "6. List available packages"
echo "7. Stow specific package"
echo "8. Unstow specific package"
echo "9. Exit"
echo ""
read -p "Select option (1-9): " OPTION

case $OPTION in
    1)
        # Clone dotfiles repository
        if [[ -d "$DOTFILES_DIR" ]]; then
            log_warn "Dotfiles directory already exists at $DOTFILES_DIR"
            read -p "Do you want to remove it and clone fresh? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$DOTFILES_DIR"
            else
                log_info "Keeping existing directory"
                exit 0
            fi
        fi

        read -p "Enter your dotfiles Git repository URL: " REPO_URL
        if [[ -z "$REPO_URL" ]]; then
            error_exit "Repository URL cannot be empty"
        fi

        log_step "Cloning dotfiles repository..."
        git clone "$REPO_URL" "$DOTFILES_DIR"

        log_info "Dotfiles cloned successfully to $DOTFILES_DIR"
        log_info "Run this script again with option 2 to deploy your dotfiles"
        ;;

    2)
        # Deploy dotfiles using stow
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR. Use option 1 to clone your repository first."
        fi

        # Check if stow is installed
        if ! command -v stow &> /dev/null; then
            log_warn "GNU Stow is not installed. Installing..."
            sudo pacman -S --needed --noconfirm stow
        fi

        log_step "Backing up existing configurations..."
        mkdir -p "$BACKUP_DIR"

        # Backup common config files before stowing
        [[ -f ~/.bashrc ]] && cp ~/.bashrc "$BACKUP_DIR/"
        [[ -f ~/.zshrc ]] && cp ~/.zshrc "$BACKUP_DIR/"
        [[ -f ~/.vimrc ]] && cp ~/.vimrc "$BACKUP_DIR/"
        [[ -f ~/.gitconfig ]] && cp ~/.gitconfig "$BACKUP_DIR/"
        [[ -f ~/.tmux.conf ]] && cp ~/.tmux.conf "$BACKUP_DIR/"
        [[ -d ~/.config ]] && cp -r ~/.config "$BACKUP_DIR/config-backup" 2>/dev/null || true

        log_info "Backup created at $BACKUP_DIR"

        log_step "Deploying dotfiles with stow..."
        cd "$DOTFILES_DIR"

        # Get all directories (packages) in dotfiles
        for package in */; do
            if [[ -d "$package" ]]; then
                package_name="${package%/}"

                # Skip .git and other hidden directories
                if [[ "$package_name" == .* ]]; then
                    continue
                fi

                log_info "Stowing package: $package_name"
                stow -v --adopt "$package_name" 2>&1 || log_warn "Failed to stow $package_name (may have conflicts)"
            fi
        done

        log_info "Dotfiles deployed successfully"
        log_info "If stow adopted any files, review changes with: cd $DOTFILES_DIR && git status"
        ;;

    3)
        # Remove dotfiles (unstow all)
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        log_step "Removing deployed dotfiles..."
        cd "$DOTFILES_DIR"

        for package in */; do
            if [[ -d "$package" ]]; then
                package_name="${package%/}"

                if [[ "$package_name" == .* ]]; then
                    continue
                fi

                log_info "Unstowing package: $package_name"
                stow -D -v "$package_name" 2>&1 || log_warn "Failed to unstow $package_name"
            fi
        done

        log_info "All dotfiles removed"
        ;;

    4)
        # Update dotfiles from remote
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
            error_exit "$DOTFILES_DIR is not a git repository"
        fi

        log_step "Updating dotfiles from remote repository..."
        cd "$DOTFILES_DIR"

        # Check for uncommitted changes
        if [[ -n $(git status -s) ]]; then
            log_warn "You have uncommitted changes in your dotfiles"
            git status -s
            read -p "Do you want to stash changes and pull? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git stash
                git pull --rebase
                git stash pop
            else
                log_info "Skipping update"
                exit 0
            fi
        else
            git pull --rebase
        fi

        log_info "Dotfiles updated successfully"
        log_info "Run option 5 to re-stow all packages with the latest changes"
        ;;

    5)
        # Re-stow all packages (useful after updates)
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        log_step "Re-stowing all packages..."
        cd "$DOTFILES_DIR"

        for package in */; do
            if [[ -d "$package" ]]; then
                package_name="${package%/}"

                if [[ "$package_name" == .* ]]; then
                    continue
                fi

                log_info "Re-stowing package: $package_name"
                stow -R -v "$package_name" 2>&1 || log_warn "Failed to re-stow $package_name"
            fi
        done

        log_info "All packages re-stowed successfully"
        ;;

    6)
        # List available packages
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        log_step "Available packages in $DOTFILES_DIR:"
        echo ""
        cd "$DOTFILES_DIR"

        for package in */; do
            if [[ -d "$package" ]]; then
                package_name="${package%/}"

                if [[ "$package_name" == .* ]]; then
                    continue
                fi

                echo "  - $package_name"

                # Show what files/dirs this package contains
                if [[ -d "$package_name" ]]; then
                    echo "    Contents:"
                    find "$package_name" -maxdepth 2 -type f -o -type d | head -5 | sed 's/^/      /'
                    file_count=$(find "$package_name" -type f | wc -l)
                    if [[ $file_count -gt 5 ]]; then
                        echo "      ... and $((file_count - 5)) more files"
                    fi
                fi
                echo ""
            fi
        done
        ;;

    7)
        # Stow specific package
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        read -p "Enter package name to stow: " PACKAGE
        if [[ -z "$PACKAGE" ]]; then
            error_exit "Package name cannot be empty"
        fi

        if [[ ! -d "$DOTFILES_DIR/$PACKAGE" ]]; then
            error_exit "Package '$PACKAGE' not found in $DOTFILES_DIR"
        fi

        log_step "Stowing package: $PACKAGE"
        cd "$DOTFILES_DIR"
        stow -v --adopt "$PACKAGE"

        log_info "Package '$PACKAGE' stowed successfully"
        ;;

    8)
        # Unstow specific package
        if [[ ! -d "$DOTFILES_DIR" ]]; then
            error_exit "Dotfiles directory not found at $DOTFILES_DIR"
        fi

        read -p "Enter package name to unstow: " PACKAGE
        if [[ -z "$PACKAGE" ]]; then
            error_exit "Package name cannot be empty"
        fi

        if [[ ! -d "$DOTFILES_DIR/$PACKAGE" ]]; then
            error_exit "Package '$PACKAGE' not found in $DOTFILES_DIR"
        fi

        log_step "Unstowing package: $PACKAGE"
        cd "$DOTFILES_DIR"
        stow -D -v "$PACKAGE"

        log_info "Package '$PACKAGE' unstowed successfully"
        ;;

    9)
        log_info "Exiting..."
        exit 0
        ;;

    *)
        log_error "Invalid option"
        exit 1
        ;;
esac

echo ""
log_info "=========================================="
log_info "  Dotfiles management completed"
log_info "=========================================="
log_info ""
log_info "Useful stow commands:"
log_info "  - Stow package:      cd ~/dotfiles && stow <package>"
log_info "  - Unstow package:    cd ~/dotfiles && stow -D <package>"
log_info "  - Re-stow package:   cd ~/dotfiles && stow -R <package>"
log_info "  - Simulate (dry-run): cd ~/dotfiles && stow -n <package>"
log_info "  - Verbose output:    cd ~/dotfiles && stow -v <package>"
log_info ""
log_info "Git workflow:"
log_info "  - Check status:      cd ~/dotfiles && git status"
log_info "  - Commit changes:    cd ~/dotfiles && git add . && git commit -m 'Update configs'"
log_info "  - Push changes:      cd ~/dotfiles && git push"
log_info "  - Pull updates:      cd ~/dotfiles && git pull --rebase"
log_info "=========================================="
