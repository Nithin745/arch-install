# packages.conf Update Changelog

## Summary of Changes

**Date:** 2025-12-04
**Backup:** packages.conf.backup

### Statistics
- **Before:** 151 lines, ~80+ packages (many duplicates)
- **After:** 180 lines, ~40 unique packages (no duplicates)
- **Packages Removed:** ~50+ (duplicates and deprecated)
- **Organization:** Completely restructured for clarity

---

## What Was Removed

### ❌ Duplicate Packages (Already in install.sh)

#### BASE_PACKAGES
- base, base-devel, linux, linux-headers, linux-firmware

#### FIRMWARE  
- sof-firmware, alsa-firmware
- amd-ucode, intel-ucode (conditionally installed by install.sh)
- All server firmware: linux-firmware-qlogic, bnx2x, liquidio, mellanox, nfp, whence

#### DRIVERS
- All GPU drivers: mesa, vulkan-*, libva-*, xf86-video-amdgpu/intel/nouveau
- All filesystem tools: ntfs-3g, dosfstools, btrfs-progs, xfsprogs, f2fs-tools
- nvidia-open-dkms, nvidia-utils, opencl-nvidia, libvdpau

#### NETWORK
- networkmanager, network-manager-applet, dhcpcd, openssh
- wireless_tools, wpa_supplicant, iwd
- bluez, bluez-utils
- dialog (rarely used utility)

#### SYSTEM UTILITIES
- sudo, man-db, man-pages, git, wget, curl, rsync
- bash-completion, usbutils, pciutils, lshw
- zip, unzip, tar, gzip, xz
- pipewire, pipewire-alsa, pipewire-pulse, pipewire-jack, wireplumber, alsa-utils
- acpi, acpid

#### DEVELOPMENT
- gcc, make, cmake, git (basic tools in install.sh)

### ❌ Deprecated/Obsolete Packages

1. **exfat-utils** → Replaced by **exfatprogs** (2020)
   - Also fixed in install.sh line 331

2. **xf86-video-fbdev** → Obsolete (modesetting driver preferred)

3. **xf86-video-vesa** → Mostly obsolete (modesetting driver preferred)

4. **xf86-video-intel** → Not recommended (modesetting driver better for modern Intel)

5. **xf86-input-evdev** → Deprecated (libinput is the modern replacement)

6. **xf86-input-synaptics** → Deprecated (libinput handles touchpads)

7. **xf86-input-wacom** → Rarely needed (libinput handles most tablets)

### ❌ Redundant/Unnecessary Packages

1. **dhcpcd** - NetworkManager already handles DHCP
2. **openresolv** - NetworkManager handles DNS resolution  
3. **dnsmasq** - Only needed for specific use cases (moved to optional)
4. **bind-tools** - dig/nslookup, useful but not essential (moved to optional)
5. **iptables-nft** - Already included with firewalld/ufw
6. **neofetch** - Kept fastfetch (faster, modern alternative)
7. **network-manager-applet** - DE-specific, not needed in base

### ❌ Both Firewalls (Chose One)

**Removed:** ufw (kept as commented alternative)
**Kept:** firewalld (per user preference)

---

## What Was Fixed

### ✅ Package Replacements

1. **exfat-utils → exfatprogs** (in install.sh line 331)
   - Modern, maintained replacement
   - Better performance and features

### ✅ Driver Modernization

- Removed all deprecated xf86-video-* drivers
- Removed all deprecated xf86-input-* drivers
- Modern systems use modesetting and libinput (already in install.sh via xorg)

---

## What Was Kept/Added

### ✅ Text Editors (NEW category)
- nano, vim, neovim

### ✅ System Monitoring (NEW category)
- htop, btop, fastfetch, dmidecode

### ✅ File Management (NEW category)
- ranger, nnn, mc, fzf, fd, ripgrep, tree

### ✅ Compression Tools (Additional)
- p7zip, bzip2, unrar
- (basic zip, tar, gzip, xz already in install.sh)

### ✅ Shell Environments
- zsh, zsh-completions

### ✅ Advanced Power Management
- tlp, powertop, thermald

### ✅ Audio Control
- pavucontrol (GUI mixer)

### ✅ Firewall
- firewalld (chose this per user preference)

### ✅ Development Tools (Advanced)
- clang, ninja, meson, automake, autoconf, pkg-config
- git-lfs, github-cli
- Optional: ccache, sccache, distcc (commented)
- Optional: gdb, valgrind, strace, ltrace, perf (commented)

### ✅ Container Tools
- podman, podman-compose, podman-docker, buildah, skopeo

### ✅ Desktop Environments (Enhanced)
- Added Cinnamon and MATE options
- Better organized with clear categories
- All properly commented out by default

### ✅ Optional Applications
- Kept and organized: browsers, office, media, etc.
- Added more options: Discord, Telegram, Thunderbird
- Added IDE options: code, geany, qtcreator

---

## New Structure

### Clear Separation
- **install.sh:** Base system + hardware-specific drivers
- **packages.conf:** Post-install additions only

### Better Organization
1. Text Editors
2. System Monitoring
3. File Management
4. Compression Tools
5. Shell Environments
6. Power Management
7. Audio Control
8. Network Utilities (optional)
9. Firewall
10. Development Tools
11. Container Tools
12. Virtualization (optional)
13. Desktop Environments (optional)
14. Applications (optional)

### Enhanced Documentation
- Clear header explaining what's already installed
- Comments on when to use each package
- Notes about alternatives (ufw vs firewalld)
- Better organization for easier maintenance

---

## Benefits

### ✅ No More Duplicates
- Eliminated ~50+ duplicate packages
- Clear separation: install.sh (base) vs packages.conf (additions)

### ✅ Modern Package Set
- Removed 6 deprecated packages
- Replaced with modern alternatives
- Up-to-date with current Arch Linux best practices

### ✅ Cleaner Installation
- Smaller, focused package list
- Faster installation (no redundant downloads)
- Less confusion about what's installed where

### ✅ Better Maintainability
- Clear categories
- Well-documented sections
- Easy to add/remove packages
- Backup preserved (packages.conf.backup)

### ✅ User Preference Applied
- firewalld (not ufw)
- No old hardware drivers
- No server firmware
- NVIDIA standard drivers (not open)

---

## Migration Notes

### For Existing Users

If you were using the old packages.conf:

1. **Backup preserved:** `packages.conf.backup`
2. **Review differences:** Compare old vs new to see what changed
3. **Check custom-packages.txt:** Your personal packages are unchanged
4. **Desktop Environment:** Re-uncomment your DE if you were using one
5. **Optional packages:** Re-enable any optional packages you need

### For New Users

1. Edit `packages.conf` and uncomment what you need
2. Choose a Desktop Environment (if you want GUI)
3. Enable optional applications (browsers, media players, etc.)
4. Add personal packages to `custom-packages.txt`
5. Run `post-install.sh` after base installation

---

## Commands to Compare

```bash
# See what was removed/changed
diff packages.conf.backup packages.conf

# Count packages before
grep -oP '\b[a-z][a-z0-9-]+' packages.conf.backup | sort -u | wc -l

# Count packages now
grep -oP '\b[a-z][a-z0-9-]+' packages.conf | sort -u | wc -l

# Restore backup if needed
cp packages.conf.backup packages.conf
```

---

## Testing

To verify the changes work correctly:

1. Run `post-install.sh` with new packages.conf
2. Verify no duplicate package errors
3. Confirm firewalld installs correctly
4. Check that exfatprogs works (not exfat-utils)
5. Verify Desktop Environment installs if enabled

---

**Maintained by:** OpenCode AI Assistant
**Date:** December 4, 2025
