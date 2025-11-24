# Arch Linux Automated Installation System

A comprehensive, modular automation system for installing and configuring Arch Linux with reproducible results every time.

## Features

- Fully automated base system installation
- Comprehensive firmware and driver support
- Modular package management
- Easy-to-maintain configuration files
- Support for both UEFI and BIOS systems
- AUR helper installation (yay)
- Dotfiles management
- Idempotent scripts (safe to run multiple times)

## Quick Start

### 1. Boot from Arch ISO

Download the latest Arch Linux ISO from [archlinux.org](https://archlinux.org/download/) and boot from it.

### 2. Prepare the Installation Files

```bash
# Connect to internet (if needed)
iwctl  # For WiFi
# or
dhcpcd # For Ethernet

# Download or copy these scripts to the live environment
# Example: using git
pacman -Sy git
git clone <your-repo-url> /root/arch-install
cd /root/arch-install
```

### 3. Configure Installation (Optional)

Create an `install.conf` file to avoid interactive prompts:

```bash
# install.conf
HOSTNAME="archlinux"
USERNAME="user"
USER_PASSWORD="your-password"
ROOT_PASSWORD="root-password"
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"
TARGET_DISK="sda"  # or nvme0n1, etc.
```

### 4. Run Base Installation

```bash
chmod +x install.sh
./install.sh
```

The script will:
- Partition and format the disk
- Install base system with all firmware and drivers
- Configure bootloader (systemd-boot for UEFI, GRUB for BIOS)
- Set up user accounts
- Configure network and essential services

### 5. Reboot and Continue

```bash
umount -R /mnt
reboot
```

### 6. Post-Installation Setup

After rebooting and logging in:

```bash
cd ~/arch-install
chmod +x post-install.sh
./post-install.sh
```

This will:
- Install AUR helper (yay)
- Install desktop environment (if configured)
- Install custom packages
- Configure additional services
- Apply system optimizations

## File Structure

```
arch-install/
├── install.sh              # Main installation script (run from ISO)
├── install.conf            # Installation configuration (optional)
├── packages.conf           # Package definitions
├── post-install.sh         # Post-installation script (run after first boot)
├── config.sh               # Dotfiles management script
├── custom-packages.txt     # Your custom package list
├── dotfiles/               # Your configuration files
└── README.md               # This file
```

## Package Management

### packages.conf

This file contains categorized package lists:

- **BASE_PACKAGES**: Essential system packages
- **FIRMWARE_PACKAGES**: Hardware firmware (Intel, AMD, WiFi, etc.)
- **DRIVER_PACKAGES**: Graphics, input, filesystem drivers
- **NETWORK_PACKAGES**: NetworkManager, WiFi, Bluetooth, SSH
- **SYSTEM_PACKAGES**: System utilities, monitoring tools
- **DEVELOPMENT_PACKAGES**: Compilers, debuggers, version control
- **CONTAINER_PACKAGES**: Podman, virtualization tools
- **DE_PACKAGES**: Desktop environment (commented by default)
- **OPTIONAL_PACKAGES**: Browsers, media players, etc. (commented by default)

### custom-packages.txt

Add your personal packages here (one per line):

```
# Official repository packages
neovim
tmux
htop

# AUR packages (prefix with "AUR:")
AUR: visual-studio-code-bin
AUR: spotify
AUR: brave-bin

# Comments are supported
# firefox  # This line is ignored
```

### Adding New Packages

You have three options:

1. **Edit packages.conf**: For permanent additions to your base system
2. **Edit custom-packages.txt**: For personal packages (recommended)
3. **Install manually**: `yay -S package-name`

To apply changes from `custom-packages.txt`, simply run `post-install.sh` again.

## Configuration Management

The `config.sh` script helps you manage your dotfiles:

```bash
chmod +x config.sh
./config.sh
```

Options:
1. **Backup**: Save current configs to timestamped backup
2. **Restore**: Apply configs from dotfiles directory
3. **Save**: Save current configs to dotfiles directory
4. **Initialize**: Create dotfiles directory structure

### Version Control Your Dotfiles

```bash
cd dotfiles
git init
git add .
git commit -m "Initial dotfiles"
git remote add origin <your-dotfiles-repo>
git push -u origin main
```

## Desktop Environments

To install a desktop environment, edit `packages.conf` and uncomment your preferred DE section:

### GNOME
```bash
DE_PACKAGES="xorg xorg-server gnome gnome-extra gdm"
```

### KDE Plasma
```bash
DE_PACKAGES="xorg xorg-server plasma plasma-wayland-session kde-applications sddm"
```

### XFCE
```bash
DE_PACKAGES="xorg xorg-server xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
```

### i3 (Window Manager)
```bash
DE_PACKAGES="xorg xorg-server i3-wm i3status i3lock dmenu rofi picom nitrogen"
```

### Hyprland (Wayland)
```bash
DE_PACKAGES="hyprland waybar wofi kitty"
```

Then run `post-install.sh` to install.

## Hardware Support

The installation includes comprehensive hardware support:

### Firmware
- Intel microcode
- AMD microcode
- WiFi firmware (Intel, Qualcomm, Broadcom, etc.)
- Sound firmware (SOF, ALSA)
- GPU firmware (AMD, Intel)

### Graphics Drivers
- Mesa (open-source)
- Vulkan (AMD, Intel, Nvidia)
- NVIDIA proprietary drivers (DKMS)
- Intel VA-API
- VDPAU

### File Systems
- ext4, btrfs, xfs, f2fs
- NTFS (ntfs-3g)
- exFAT
- FAT32

## Troubleshooting

### No Internet After Reboot

```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
nmtui  # Text UI for network configuration
```

### WiFi Not Working

```bash
# Check if driver is loaded
lspci -k | grep -A 3 -i "network"

# Install additional firmware if needed
sudo pacman -S linux-firmware
```

### Graphics Issues

```bash
# Check loaded drivers
lspci -k | grep -A 3 -i "vga"

# For NVIDIA, you may need to blacklist nouveau
sudo vim /etc/modprobe.d/blacklist-nouveau.conf
# Add: blacklist nouveau

# Regenerate initramfs
sudo mkinitcpio -P
```

### Boot Issues

Boot from Arch ISO and:

```bash
# Mount your partitions
mount /dev/sdXY /mnt
mount /dev/sdXZ /mnt/boot  # If UEFI

# Chroot into system
arch-chroot /mnt

# Reinstall bootloader
bootctl install  # For UEFI
# or
grub-install /dev/sdX && grub-mkconfig -o /boot/grub/grub.cfg  # For BIOS
```

## Customization

### Modify Installation Behavior

Edit `install.sh` to change:
- Partition scheme
- File system types
- Bootloader configuration
- Default services

### Add Custom Services

In `post-install.sh`, add:

```bash
if systemctl list-unit-files | grep -q your-service.service; then
    sudo systemctl enable your-service.service
    log_info "Your service enabled"
fi
```

### Pre-configure Applications

Add configuration scripts to `config.sh` or create new scripts in the directory.

## Best Practices

1. **Always backup**: Use `config.sh` to backup before major changes
2. **Test in VM**: Try the installation in a virtual machine first
3. **Version control**: Keep your customizations in git
4. **Document changes**: Comment your modifications in packages.conf
5. **Incremental updates**: Add new packages to custom-packages.txt, not packages.conf
6. **Regular updates**: Run `sudo pacman -Syu` weekly

## Maintenance

### System Update
```bash
paru -Syu  # Updates both official and AUR packages
```

### Clean Package Cache
```bash
paru -Sc
```

### Remove Orphaned Packages
```bash
sudo pacman -Rns $(pacman -Qtdq)
```

### Update Mirrors
```bash
sudo pacman -S reflector
sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

## Security Considerations

1. **Change default passwords**: Modify or remove them from install.conf
2. **Enable firewall**: UFW is installed and enabled by default
3. **Keep system updated**: Regular updates are critical
4. **Review AUR packages**: Always check PKGBUILD before installing from AUR
5. **Secure SSH**: If using SSH, consider key-based authentication

## Contributing

Feel free to customize these scripts for your needs. If you make improvements:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Submit a pull request

## Resources

- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [AUR Guidelines](https://wiki.archlinux.org/title/Arch_User_Repository)
- [Arch Linux Forums](https://bbs.archlinux.org/)

## License

These scripts are provided as-is for educational and personal use.

## Disclaimer

**WARNING**: These scripts will format the specified disk and erase all data. Always backup your data before running installation scripts. The authors are not responsible for any data loss or system damage.

---

**Last Updated**: 2025

For questions or issues, please open an issue on the repository.
