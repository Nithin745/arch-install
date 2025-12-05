#!/bin/bash
# Arch Linux Post-Installation Script
# Run this after first boot into your new Arch system
# This script installs AUR helper, custom packages, and configures user environment

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

# Check if not running as root
if [[ $EUID -eq 0 ]]; then
   error_exit "This script should NOT be run as root. Run as your regular user."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear
echo "=========================================="
echo "  Arch Linux Post-Installation Script"
echo "=========================================="
echo ""

# Update system
log_step "Updating system packages..."
sudo pacman -Syu --noconfirm

# Install paru (AUR helper)
log_step "Installing paru (AUR helper)..."
if command -v paru &> /dev/null; then
    log_info "paru is already installed"
else
    log_info "Building and installing paru..."
    cd /tmp
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    log_info "paru installed successfully"
fi

# Install packages from packages.conf
PACKAGES_FILE="${SCRIPT_DIR}/packages.conf"
if [[ -f "$PACKAGES_FILE" ]]; then
    log_step "Installing additional packages from packages.conf..."

    # Source the packages.conf file to load all *_PACKAGES variables
    # This dynamically reads all package category variables
    source "$PACKAGES_FILE"

    # Define package categories to install (in order)
    # Format: "VARIABLE_NAME:Display Name"
    PACKAGE_CATEGORIES=(
        "EDITOR_PACKAGES:Text Editors"
        "MONITORING_PACKAGES:System Monitoring"
        "FILEMANAGER_PACKAGES:File Management Utilities"
        "COMPRESSION_PACKAGES:Compression Tools"
        "SHELL_PACKAGES:Shell Environments"
        "POWER_PACKAGES:Power Management"
        "AUDIO_PACKAGES:Audio Control"
        "NETWORK_UTILITIES:Network Utilities"
        "FIREWALL_PACKAGES:Firewall"
        "DEVELOPMENT_PACKAGES:Development Tools"
        "CONTAINER_PACKAGES:Container Tools"
        "VIRTUALIZATION_PACKAGES:Virtualization"
        "PRINTING_PACKAGES:Printing Support"
        "DE_PACKAGES:Desktop Environment"
        "OPTIONAL_PACKAGES:Optional Applications"
    )

    # Install packages for each category
    for category in "${PACKAGE_CATEGORIES[@]}"; do
        VAR_NAME="${category%%:*}"
        DISPLAY_NAME="${category#*:}"
        
        # Get the value of the variable
        PACKAGES="${!VAR_NAME}"
        
        # Skip if variable is empty or not set
        if [[ -n "$PACKAGES" ]]; then
            log_info "Installing $DISPLAY_NAME..."
            sudo pacman -S --needed --noconfirm $PACKAGES || log_warn "Some $DISPLAY_NAME packages failed to install"
        fi
    done

    # Special handling: Configure podman for rootless operation if installed
    if command -v podman &> /dev/null; then
        log_info "Configuring podman for rootless operation..."
        sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER 2>/dev/null || true
        podman system migrate 2>/dev/null || true
    fi
fi

# Install custom packages
CUSTOM_PACKAGES_FILE="${SCRIPT_DIR}/custom-packages.txt"
if [[ -f "$CUSTOM_PACKAGES_FILE" ]]; then
    log_step "Installing custom packages from custom-packages.txt..."

    # Separate official and AUR packages
    OFFICIAL_PKGS=()
    AUR_PKGS=()

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check if it's an AUR package
        if [[ "$line" =~ ^AUR: ]]; then
            pkg=$(echo "$line" | sed 's/^AUR:[[:space:]]*//')
            AUR_PKGS+=("$pkg")
        else
            OFFICIAL_PKGS+=("$line")
        fi
    done < "$CUSTOM_PACKAGES_FILE"

    # Install official packages
    if [[ ${#OFFICIAL_PKGS[@]} -gt 0 ]]; then
        log_info "Installing official packages: ${OFFICIAL_PKGS[*]}"
        sudo pacman -S --needed --noconfirm "${OFFICIAL_PKGS[@]}" || log_warn "Some official packages failed to install"
    fi

    # Install AUR packages
    if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
        log_info "Installing AUR packages: ${AUR_PKGS[*]}"
        paru -S --needed --noconfirm "${AUR_PKGS[@]}" || log_warn "Some AUR packages failed to install"
    fi
else
    log_warn "custom-packages.txt not found, skipping custom package installation"
fi

# Enable services
log_step "Enabling system services..."

# Enable power management
if systemctl list-unit-files | grep -q tlp.service; then
    sudo systemctl enable tlp.service
    log_info "TLP power management enabled"
fi

# Enable Bluetooth
if systemctl list-unit-files | grep -q bluetooth.service; then
    sudo systemctl enable bluetooth.service
    log_info "Bluetooth service enabled"
fi

# Enable CUPS printing (if installed)
if systemctl list-unit-files | grep -q cups.service; then
    sudo systemctl enable cups.service
    log_info "CUPS printing service enabled"
fi

# Enable display manager (if installed)
if systemctl list-unit-files | grep -q gdm.service; then
    sudo systemctl enable gdm.service
    log_info "GDM display manager enabled"
elif systemctl list-unit-files | grep -q sddm.service; then
    sudo systemctl enable sddm.service
    log_info "SDDM display manager enabled"
elif systemctl list-unit-files | grep -q lightdm.service; then
    sudo systemctl enable lightdm.service
    log_info "LightDM display manager enabled"
fi

# Enable libvirtd (if installed)
if systemctl list-unit-files | grep -q libvirtd.service; then
    sudo systemctl enable libvirtd.service
    sudo usermod -aG libvirt $USER
    log_info "Libvirt virtualization enabled"
fi

# Enable firewall
if command -v ufw &> /dev/null; then
    sudo ufw enable
    sudo systemctl enable ufw.service
    log_info "UFW firewall enabled"
fi

# Configure shell
log_step "Configuring shell environment..."

# Check if user wants to switch to zsh
if command -v zsh &> /dev/null; then
    CURRENT_SHELL=$(basename "$SHELL")
    if [[ "$CURRENT_SHELL" != "zsh" ]]; then
        read -p "Do you want to switch to zsh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            chsh -s $(which zsh)
            log_info "Default shell changed to zsh (logout and login to apply)"

            # Install oh-my-zsh
            if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
                read -p "Do you want to install oh-my-zsh? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
                    log_info "oh-my-zsh installed"
                fi
            fi
        fi
    fi
fi

# System optimization
log_step "Applying system optimizations..."

# Improve makepkg build times
if [[ -f /etc/makepkg.conf ]]; then
    sudo sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf
    log_info "makepkg configured to use all CPU cores"
fi

# Enable periodic TRIM for SSDs
if systemctl list-unit-files | grep -q fstrim.timer; then
    sudo systemctl enable fstrim.timer
    log_info "Periodic TRIM enabled for SSDs"
fi

# Create common directories
log_step "Creating user directories..."
mkdir -p ~/Documents ~/Downloads ~/Pictures ~/Videos ~/Music ~/Projects ~/Desktop
xdg-user-dirs-update 2>/dev/null || true

# Run config script if available
CONFIG_SCRIPT="${SCRIPT_DIR}/config.sh"
if [[ -f "$CONFIG_SCRIPT" && -x "$CONFIG_SCRIPT" ]]; then
    log_step "Running configuration script..."
    "$CONFIG_SCRIPT"
fi

# Clean up
log_step "Cleaning up..."
sudo pacman -Sc --noconfirm
paru -Sc --noconfirm

# Final message
echo ""
log_info "=========================================="
log_info "  Post-installation completed!"
log_info "=========================================="
log_info ""
log_info "Next steps:"
log_info "1. Review and customize ~/arch-install/custom-packages.txt"
log_info "2. Run this script again to install additional packages"
log_info "3. Configure your desktop environment/window manager"
log_info "4. Set up your dotfiles using config.sh"
log_info "5. Reboot if shell was changed or drivers were installed"
log_info ""
log_info "Useful commands:"
log_info "  - Update system: sudo pacman -Syu"
log_info "  - Install AUR package: paru -S package-name"
log_info "  - Search packages: paru -Ss package-name"
log_info "  - Clean cache: paru -Sc"
log_info "=========================================="
