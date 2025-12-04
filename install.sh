#!/bin/bash
# Arch Linux Base Installation Script
# This script automates the base installation of Arch Linux
# Run this script from the Arch Linux ISO environment

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error_exit "This script must be run as root (boot from Arch ISO)"
fi

# Welcome message
clear
echo "======================================"
echo "  Arch Linux Installation Script"
echo "======================================"
echo ""

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/install.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    log_info "Loading configuration from install.conf"
    source "$CONFIG_FILE"
else
    log_warn "No install.conf found, using interactive mode"

    # Get user input
    read -p "Enter hostname: " HOSTNAME
    read -p "Enter username: " USERNAME
    read -s -p "Enter password for $USERNAME: " USER_PASSWORD
    echo ""
    read -s -p "Enter root password: " ROOT_PASSWORD
    echo ""
    read -p "Enter timezone (e.g., America/New_York): " TIMEZONE
    read -p "Enter locale (e.g., en_US.UTF-8): " LOCALE
    read -p "Enter keymap (e.g., us): " KEYMAP

    # Filesystem selection
    echo ""
    log_info "Filesystem options:"
    echo "1. btrfs (recommended - with subvolumes and snapshots)"
    echo "2. ext4 (traditional - simple and reliable)"
    read -p "Select filesystem (1-2): " FS_CHOICE
    case $FS_CHOICE in
        1) FILESYSTEM="btrfs" ;;
        2) FILESYSTEM="ext4" ;;
        *) FILESYSTEM="btrfs" ;;
    esac

    # Kernel selection
    echo ""
    log_info "Linux kernel options:"
    echo "1. stable (latest stable kernel - newest features and hardware support)"
    echo "2. lts (Long Term Support - more stable, longer security updates)"
    read -p "Select kernel (1-2): " KERNEL_CHOICE
    case $KERNEL_CHOICE in
        1) KERNEL="stable" ;;
        2) KERNEL="lts" ;;
        *) KERNEL="stable" ;;
    esac

    # Disk selection
    echo ""
    log_info "Available disks:"
    lsblk -d -n -o NAME,SIZE,TYPE | grep disk
    read -p "Enter target disk (e.g., sda, nvme0n1): " TARGET_DISK

    # Confirm
    log_warn "WARNING: This will ERASE ALL DATA on /dev/${TARGET_DISK}"
    read -p "Are you sure? (type 'YES' to continue): " CONFIRM
    if [[ "$CONFIRM" != "YES" ]]; then
        error_exit "Installation cancelled"
    fi
fi

# Set defaults
HOSTNAME="${HOSTNAME:-archlinux}"
USERNAME="${USERNAME:-user}"
TIMEZONE="${TIMEZONE:-UTC}"
LOCALE="${LOCALE:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-us}"
TARGET_DISK="${TARGET_DISK:-sda}"
FILESYSTEM="${FILESYSTEM:-btrfs}"
KERNEL="${KERNEL:-stable}"

# Verify internet connection
log_step "Checking internet connectivity..."
if ping -c 3 archlinux.org &> /dev/null; then
    log_info "Internet connection verified"
else
    error_exit "No internet connection. Please configure network first."
fi

# Detect hardware
log_step "Detecting hardware..."

# Detect CPU vendor
if grep -q "GenuineIntel" /proc/cpuinfo; then
    CPU_VENDOR="intel"
    log_info "Intel CPU detected"
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
    CPU_VENDOR="amd"
    log_info "AMD CPU detected"
else
    CPU_VENDOR="unknown"
    log_warn "Unknown CPU vendor"
fi

# Detect GPU
GPU_DETECTED=""
if lspci | grep -i "vga\|3d\|display" | grep -iq "nvidia"; then
    GPU_DETECTED="nvidia"
    log_info "NVIDIA GPU detected"
fi
if lspci | grep -i "vga\|3d\|display" | grep -iq "amd\|radeon"; then
    if [[ -n "$GPU_DETECTED" ]]; then
        GPU_DETECTED="${GPU_DETECTED} amd"
    else
        GPU_DETECTED="amd"
    fi
    log_info "AMD GPU detected"
fi
if lspci | grep -i "vga\|3d\|display" | grep -iq "intel"; then
    if [[ -n "$GPU_DETECTED" ]]; then
        GPU_DETECTED="${GPU_DETECTED} intel"
    else
        GPU_DETECTED="intel"
    fi
    log_info "Intel GPU detected"
fi

if [[ -z "$GPU_DETECTED" ]]; then
    log_warn "No GPU detected or generic VGA"
    GPU_DETECTED="generic"
fi

# Detect wireless hardware
HAS_WIRELESS="no"
if lspci | grep -iq "network\|wireless\|wifi" || lsusb | grep -iq "wireless\|wifi"; then
    HAS_WIRELESS="yes"
    log_info "Wireless hardware detected"
fi

# Detect Bluetooth hardware
HAS_BLUETOOTH="no"
if lsusb | grep -iq "bluetooth" || lspci | grep -iq "bluetooth"; then
    HAS_BLUETOOTH="yes"
    log_info "Bluetooth hardware detected"
fi

# Update system clock
log_step "Updating system clock..."
timedatectl set-ntp true

# Partition the disk
log_step "Partitioning disk /dev/${TARGET_DISK}..."

# Detect if UEFI or BIOS
if [[ -d /sys/firmware/efi/efivars ]]; then
    BOOT_MODE="UEFI"
    log_info "UEFI boot mode detected"
else
    BOOT_MODE="BIOS"
    log_info "BIOS boot mode detected"
fi

# Wipe disk
wipefs -af "/dev/${TARGET_DISK}"
sgdisk --zap-all "/dev/${TARGET_DISK}"

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    # UEFI partitioning
    parted -s "/dev/${TARGET_DISK}" mklabel gpt
    parted -s "/dev/${TARGET_DISK}" mkpart ESP fat32 1MiB 512MiB
    parted -s "/dev/${TARGET_DISK}" set 1 esp on
    parted -s "/dev/${TARGET_DISK}" mkpart primary ${FILESYSTEM} 512MiB 100%

    # Get partition names
    if [[ "${TARGET_DISK}" =~ "nvme" ]]; then
        BOOT_PART="/dev/${TARGET_DISK}p1"
        ROOT_PART="/dev/${TARGET_DISK}p2"
    else
        BOOT_PART="/dev/${TARGET_DISK}1"
        ROOT_PART="/dev/${TARGET_DISK}2"
    fi

    # Format boot partition
    mkfs.fat -F32 "${BOOT_PART}"

    # Format root partition based on filesystem choice
    if [[ "$FILESYSTEM" == "btrfs" ]]; then
        log_info "Creating btrfs filesystem with optimal settings..."
        mkfs.btrfs -f -L arch "${ROOT_PART}"

        # Mount and create subvolumes
        mount "${ROOT_PART}" /mnt

        log_info "Creating btrfs subvolumes for Timeshift compatibility..."
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@var_log

        # Unmount to remount with subvolumes
        umount /mnt

        # Mount with optimal options
        BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,commit=120,discard=async"
        mount -o ${BTRFS_OPTS},subvol=@ "${ROOT_PART}" /mnt

        # Create mount points
        mkdir -p /mnt/{home,var/log,boot}

        # Mount subvolumes
        mount -o ${BTRFS_OPTS},subvol=@home "${ROOT_PART}" /mnt/home
        mkdir -p /mnt/var/log
        mount -o ${BTRFS_OPTS},subvol=@var_log "${ROOT_PART}" /mnt/var/log

        log_info "Btrfs subvolumes created and mounted with optimal options"
    else
        mkfs.ext4 -F "${ROOT_PART}"
        mount "${ROOT_PART}" /mnt
        mkdir -p /mnt/boot
    fi

    # Mount boot partition
    mount "${BOOT_PART}" /mnt/boot
else
    # BIOS partitioning
    parted -s "/dev/${TARGET_DISK}" mklabel msdos
    parted -s "/dev/${TARGET_DISK}" mkpart primary ${FILESYSTEM} 1MiB 100%
    parted -s "/dev/${TARGET_DISK}" set 1 boot on

    # Get partition name
    if [[ "${TARGET_DISK}" =~ "nvme" ]]; then
        ROOT_PART="/dev/${TARGET_DISK}p1"
    else
        ROOT_PART="/dev/${TARGET_DISK}1"
    fi

    # Format and mount based on filesystem choice
    if [[ "$FILESYSTEM" == "btrfs" ]]; then
        log_info "Creating btrfs filesystem with optimal settings..."
        mkfs.btrfs -f -L arch "${ROOT_PART}"

        # Mount and create subvolumes
        mount "${ROOT_PART}" /mnt

        log_info "Creating btrfs subvolumes for Timeshift compatibility..."
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@var_log

        # Unmount to remount with subvolumes
        umount /mnt

        # Mount with optimal options
        BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,commit=120,discard=async"
        mount -o ${BTRFS_OPTS},subvol=@ "${ROOT_PART}" /mnt

        # Create mount points
        mkdir -p /mnt/{home,var/log,boot}

        # Mount subvolumes
        mount -o ${BTRFS_OPTS},subvol=@home "${ROOT_PART}" /mnt/home
        mkdir -p /mnt/var/log
        mount -o ${BTRFS_OPTS},subvol=@var_log "${ROOT_PART}" /mnt/var/log

        log_info "Btrfs subvolumes created and mounted with optimal options"
    else
        mkfs.ext4 -F "${ROOT_PART}"
        mount "${ROOT_PART}" /mnt
        mkdir -p /mnt/boot
    fi
fi

log_info "Disk partitioned and mounted successfully"

# Build package list based on hardware
log_step "Building package list based on detected hardware..."

# Base packages - kernel selection
if [[ "$KERNEL" == "lts" ]]; then
    log_info "Using Linux LTS kernel"
    BASE_PACKAGES="base base-devel linux-lts linux-lts-headers linux-firmware"
else
    log_info "Using Linux stable kernel"
    BASE_PACKAGES="base base-devel linux linux-headers linux-firmware"
fi

# Filesystem tools
if [[ "$FILESYSTEM" == "btrfs" ]]; then
    FILESYSTEM_PACKAGES="btrfs-progs timeshift"
else
    FILESYSTEM_PACKAGES="e2fsprogs"
fi

# Add other filesystem support
FILESYSTEM_PACKAGES="$FILESYSTEM_PACKAGES ntfs-3g exfat-utils dosfstools xfsprogs f2fs-tools"

# CPU microcode
if [[ "$CPU_VENDOR" == "intel" ]]; then
    CPU_PACKAGES="intel-ucode"
elif [[ "$CPU_VENDOR" == "amd" ]]; then
    CPU_PACKAGES="amd-ucode"
else
    CPU_PACKAGES=""
fi

# Firmware packages
FIRMWARE_PACKAGES="linux-firmware sof-firmware alsa-firmware"
if [[ "$HAS_WIRELESS" == "yes" ]]; then
    log_info "Including wireless firmware"
fi

# GPU drivers
GPU_PACKAGES="mesa vulkan-icd-loader"
if echo "$GPU_DETECTED" | grep -q "nvidia"; then
    GPU_PACKAGES="$GPU_PACKAGES nvidia-dkms nvidia-utils opencl-nvidia libvdpau"
    log_info "Including NVIDIA drivers"
fi
if echo "$GPU_DETECTED" | grep -q "amd"; then
    GPU_PACKAGES="$GPU_PACKAGES vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-amdgpu"
    log_info "Including AMD drivers"
fi
if echo "$GPU_DETECTED" | grep -q "intel"; then
    GPU_PACKAGES="$GPU_PACKAGES vulkan-intel libva-intel-driver intel-media-driver xf86-video-intel"
    log_info "Including Intel drivers"
fi

# Network packages
NETWORK_PACKAGES="networkmanager dhcpcd openssh"
if [[ "$HAS_WIRELESS" == "yes" ]]; then
    NETWORK_PACKAGES="$NETWORK_PACKAGES wpa_supplicant iwd wireless_tools"
fi
if [[ "$HAS_BLUETOOTH" == "yes" ]]; then
    NETWORK_PACKAGES="$NETWORK_PACKAGES bluez bluez-utils"
    log_info "Including Bluetooth support"
fi

# System utilities
SYSTEM_PACKAGES="sudo man-db man-pages git wget curl rsync stow"
SYSTEM_PACKAGES="$SYSTEM_PACKAGES bash-completion usbutils pciutils lshw"
SYSTEM_PACKAGES="$SYSTEM_PACKAGES zip unzip tar gzip xz"

# Audio
AUDIO_PACKAGES="pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber alsa-utils"

# Power management
POWER_PACKAGES="acpi acpid"

# Development
DEV_PACKAGES="gcc make cmake git"

# Combine all packages
PACSTRAP_PACKAGES="$BASE_PACKAGES $FILESYSTEM_PACKAGES $CPU_PACKAGES $FIRMWARE_PACKAGES $GPU_PACKAGES $NETWORK_PACKAGES $SYSTEM_PACKAGES $AUDIO_PACKAGES $POWER_PACKAGES $DEV_PACKAGES"

log_info "Installing: $(echo $PACSTRAP_PACKAGES | wc -w) packages"

# Install packages
pacstrap -K /mnt $PACSTRAP_PACKAGES

log_info "Base system installed successfully"

# Generate fstab
log_step "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Configure system
log_step "Configuring system..."

# Create chroot configuration script
cat > /mnt/root/chroot-config.sh << 'EOFCHROOT'
#!/bin/bash
set -e

# Set timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# Set locale
echo "${LOCALE} UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Set keymap
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# Set root password
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user
useradd -m -G wheel,audio,video,optical,storage,power -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Configure sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Configure mkinitcpio for filesystem
if [[ "$FILESYSTEM" == "btrfs" ]]; then
    sed -i 's/^MODULES=()/MODULES=(btrfs)/' /etc/mkinitcpio.conf
fi

# Regenerate initramfs
mkinitcpio -P

# Install and configure bootloader
if [[ -d /sys/firmware/efi/efivars ]]; then
    # UEFI
    bootctl install

    cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 5
console-mode max
editor no
EOF

    # Build kernel parameters
    KERNEL_PARAMS="root=PARTUUID=$(blkid -s PARTUUID -o value ${ROOT_PART}) rw"

    if [[ "$FILESYSTEM" == "btrfs" ]]; then
        KERNEL_PARAMS="$KERNEL_PARAMS rootflags=subvol=@"
    fi

    # Add NVIDIA DRM modeset if NVIDIA detected
    if echo "$GPU_DETECTED" | grep -q "nvidia"; then
        KERNEL_PARAMS="$KERNEL_PARAMS nvidia-drm.modeset=1"
    fi

    # Build systemd-boot entry with CPU microcode
    cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
EOF

    # Add CPU microcode if available
    if [[ "$CPU_VENDOR" == "intel" ]]; then
        echo "initrd  /intel-ucode.img" >> /boot/loader/entries/arch.conf
    elif [[ "$CPU_VENDOR" == "amd" ]]; then
        echo "initrd  /amd-ucode.img" >> /boot/loader/entries/arch.conf
    fi

    # Add main initramfs and kernel parameters
    cat >> /boot/loader/entries/arch.conf << EOF
initrd  /initramfs-linux.img
options $KERNEL_PARAMS
EOF
else
    # BIOS
    pacman -S --noconfirm grub
    grub-install --target=i386-pc "/dev/${TARGET_DISK}"

    # Configure GRUB kernel parameters
    GRUB_PARAMS=""
    
    # Add btrfs subvolume parameter if needed
    if [[ "$FILESYSTEM" == "btrfs" ]]; then
        GRUB_PARAMS="$GRUB_PARAMS rootflags=subvol=@"
    fi

    # Add NVIDIA parameters if needed
    if echo "$GPU_DETECTED" | grep -q "nvidia"; then
        GRUB_PARAMS="$GRUB_PARAMS nvidia-drm.modeset=1"
    fi

    # Update GRUB_CMDLINE_LINUX_DEFAULT if we have parameters to add
    if [[ -n "$GRUB_PARAMS" ]]; then
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1$GRUB_PARAMS\"/" /etc/default/grub
    fi

    grub-mkconfig -o /boot/grub/grub.cfg
fi

# Enable essential services
systemctl enable NetworkManager
systemctl enable systemd-timesyncd

# Enable Bluetooth if detected
if [[ "$HAS_BLUETOOTH" == "yes" ]]; then
    systemctl enable bluetooth.service
fi

# Enable fstrim for SSDs
if [[ "$FILESYSTEM" == "btrfs" ]] || [[ "$FILESYSTEM" == "ext4" ]]; then
    systemctl enable fstrim.timer
fi

# Configure timeshift for btrfs
if [[ "$FILESYSTEM" == "btrfs" ]]; then
    # Timeshift will create its own directories on first run
    # No need to pre-create /run directories as they're temporary (tmpfs)
    
    echo "Timeshift installed. Configure it after first boot using 'sudo timeshift-gtk' or 'sudo timeshift --create'"
fi

# Configure pacman
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

# Update package database
pacman -Sy

echo "Chroot configuration completed successfully"
EOFCHROOT

# Export variables for chroot script
cat > /mnt/root/chroot-env.sh << EOF
export TIMEZONE="${TIMEZONE}"
export LOCALE="${LOCALE}"
export KEYMAP="${KEYMAP}"
export HOSTNAME="${HOSTNAME}"
export USERNAME="${USERNAME}"
export USER_PASSWORD="${USER_PASSWORD}"
export ROOT_PASSWORD="${ROOT_PASSWORD}"
export ROOT_PART="${ROOT_PART}"
export TARGET_DISK="${TARGET_DISK}"
export FILESYSTEM="${FILESYSTEM}"
export CPU_VENDOR="${CPU_VENDOR}"
export GPU_DETECTED="${GPU_DETECTED}"
export HAS_BLUETOOTH="${HAS_BLUETOOTH}"
EOF

# Make scripts executable
chmod +x /mnt/root/chroot-config.sh

# Run chroot configuration
arch-chroot /mnt /bin/bash -c "source /root/chroot-env.sh && /root/chroot-config.sh"

# Copy installation files to new system
log_step "Copying installation files to new system..."
mkdir -p /mnt/home/${USERNAME}/arch-install
cp -r "${SCRIPT_DIR}"/* /mnt/home/${USERNAME}/arch-install/ 2>/dev/null || true
arch-chroot /mnt chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/arch-install

# Cleanup
rm /mnt/root/chroot-config.sh
rm /mnt/root/chroot-env.sh

# Final message
echo ""
log_info "======================================"
log_info "  Base installation completed!"
log_info "======================================"
log_info ""
log_info "Next steps:"
log_info "1. Unmount: umount -R /mnt"
log_info "2. Reboot: reboot"
log_info "3. After reboot, login and run: ~/arch-install/post-install.sh"
log_info ""
log_info "System details:"
log_info "  Hostname: ${HOSTNAME}"
log_info "  Username: ${USERNAME}"
log_info "  Timezone: ${TIMEZONE}"
log_info "  Boot mode: ${BOOT_MODE}"
log_info "  Filesystem: ${FILESYSTEM}"
log_info "  CPU: ${CPU_VENDOR}"
log_info "  GPU: ${GPU_DETECTED}"
log_info "======================================"
