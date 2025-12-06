# Disk Partitioning, Formatting, and Mounting

This document explains in detail how the installation script handles disk preparation, partitioning, formatting, and mounting for Arch Linux installation.

---

## Overview

The script supports:
- **Boot Modes:** UEFI and Legacy BIOS
- **Filesystems:** btrfs (with subvolumes) and ext4
- **Disk Types:** SATA/SCSI (sda, sdb), NVMe (nvme0n1), Virtual (vda)

---

## Phase 1: Disk Preparation

### Step 1.1: Wipe Existing Data
```bash
wipefs -af "/dev/${TARGET_DISK}"
sgdisk --zap-all "/dev/${TARGET_DISK}"
```

**What this does:**
- `wipefs -af`: Removes all filesystem, RAID, and partition signatures from the disk
  - `-a`: All signatures (filesystems, RAID metadata, GPT/MBR tables)
  - `-f`: Force operation without prompts
- `sgdisk --zap-all`: Destroys GPT and MBD data structures
  - Ensures a completely clean disk state
  - Prevents conflicts from previous partition tables

**Why both commands?**
- Defense in depth: Ensures no remnants of old data remain
- `wipefs` removes filesystem signatures
- `sgdisk` removes partition table structures
- Together they guarantee a clean slate

---

## Phase 2: Partitioning

The partitioning strategy differs based on the boot mode detected during hardware detection.

### UEFI Mode Partitioning

```bash
parted -s "/dev/${TARGET_DISK}" mklabel gpt
parted -s "/dev/${TARGET_DISK}" mkpart ESP fat32 1MiB 512MiB
parted -s "/dev/${TARGET_DISK}" set 1 esp on
parted -s "/dev/${TARGET_DISK}" mkpart primary ${FILESYSTEM} 512MiB 100%
```

**Partition Layout:**

| Partition | Size | Type | Purpose | Flags |
|-----------|------|------|---------|-------|
| Part 1 | 512 MiB | FAT32 | EFI System Partition (ESP) | esp |
| Part 2 | Remaining | btrfs/ext4 | Root filesystem | - |

**Command Breakdown:**

1. **`mklabel gpt`**: Creates a GPT (GUID Partition Table)
   - Required for UEFI systems
   - Supports disks > 2TB
   - More robust than MBR

2. **`mkpart ESP fat32 1MiB 512MiB`**: Creates EFI System Partition
   - Starts at 1MiB (for alignment)
   - 512MiB size (standard UEFI requirement)
   - Will hold bootloader and kernel images

3. **`set 1 esp on`**: Marks partition as EFI System Partition
   - UEFI firmware looks for this flag
   - Required for proper boot

4. **`mkpart primary ${FILESYSTEM} 512MiB 100%`**: Creates root partition
   - Uses remaining disk space
   - Will hold entire Linux system

**Why start at 1MiB?**
- Modern disks use 4K sectors
- Starting at 1MiB ensures proper alignment
- Improves performance and disk longevity

### Legacy BIOS Mode Partitioning

```bash
parted -s "/dev/${TARGET_DISK}" mklabel msdos
parted -s "/dev/${TARGET_DISK}" mkpart primary ${FILESYSTEM} 1MiB 100%
parted -s "/dev/${TARGET_DISK}" set 1 boot on
```

**Partition Layout:**

| Partition | Size | Type | Purpose | Flags |
|-----------|------|------|---------|-------|
| Part 1 | Entire disk | btrfs/ext4 | Root filesystem (includes /boot) | boot |

**Command Breakdown:**

1. **`mklabel msdos`**: Creates MBR (Master Boot Record)
   - Standard for BIOS systems
   - Compatible with older hardware

2. **`mkpart primary ${FILESYSTEM} 1MiB 100%`**: Single partition
   - Uses entire disk
   - Contains both /boot and root filesystem

3. **`set 1 boot on`**: Sets boot flag
   - Legacy BIOS looks for this flag
   - Required for bootloader installation

---

## Phase 3: Partition Device Naming

```bash
if [[ "${TARGET_DISK}" =~ "nvme" ]]; then
    BOOT_PART="/dev/${TARGET_DISK}p1"
    ROOT_PART="/dev/${TARGET_DISK}p2"
else
    BOOT_PART="/dev/${TARGET_DISK}1"
    ROOT_PART="/dev/${TARGET_DISK}2"
fi
```

**Why different naming?**

| Disk Type | Disk Name | Partition 1 | Partition 2 |
|-----------|-----------|-------------|-------------|
| SATA/SCSI | /dev/sda | /dev/sda1 | /dev/sda2 |
| NVMe | /dev/nvme0n1 | /dev/nvme0n1p1 | /dev/nvme0n1p2 |
| Virtual | /dev/vda | /dev/vda1 | /dev/vda2 |

NVMe drives use `p` prefix for partitions because the device name already ends in a number.

---

## Phase 4: Filesystem Creation

### UEFI: Boot Partition (ESP)

```bash
mkfs.fat -F32 "${BOOT_PART}"
```

**Format as FAT32:**
- UEFI specification requires FAT32
- Compatible with UEFI firmware
- Stores bootloader (GRUB/systemd-boot)
- Stores kernel and initramfs

### Root Partition: btrfs

```bash
mkfs.btrfs -f -L arch "${ROOT_PART}"
```

**Options:**
- `-f`: Force creation (overwrites existing data)
- `-L arch`: Sets filesystem label to "arch"

**Why btrfs?**
- **Snapshots**: System rollback capability with Timeshift
- **Compression**: Saves disk space (zstd algorithm)
- **Subvolumes**: Flexible filesystem organization
- **Copy-on-Write**: Data integrity and efficient snapshots
- **Self-healing**: Checksums for data corruption detection

### Root Partition: ext4

```bash
mkfs.ext4 -F "${ROOT_PART}"
```

**Options:**
- `-F`: Force creation (overwrites existing data)

**Why ext4?**
- **Mature and stable**: Battle-tested filesystem
- **Simple**: No complexity of subvolumes
- **Fast**: Excellent performance
- **Universal support**: Works everywhere
- **Lower overhead**: Slightly less resource usage

---

## Phase 5: btrfs Subvolume Creation

For btrfs filesystem only:

```bash
mount "${ROOT_PART}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
umount /mnt
```

### Subvolume Structure

| Subvolume | Mount Point | Purpose | Snapshot Policy |
|-----------|-------------|---------|-----------------|
| @ | / | Root filesystem | Yes - for rollback |
| @home | /home | User data | Optional - less frequent |
| @var_log | /var/log | System logs | No - exclude from snapshots |

**Why these subvolumes?**

1. **@ (root)**
   - Contains system files
   - Snapshot before updates
   - Enables system rollback

2. **@home (user data)**
   - Keeps user files separate
   - Can snapshot independently
   - Rollback system without losing user data

3. **@var_log (logs)**
   - Excluded from snapshots
   - Prevents snapshot bloat from logs
   - Logs shouldn't be rolled back

**Timeshift Compatibility:**
This layout follows Timeshift's expected structure for proper snapshot management.

---

## Phase 6: Mounting with Optimal Options

### btrfs Mount Options

```bash
BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,commit=120,discard=async"

mount -o ${BTRFS_OPTS},subvol=@ "${ROOT_PART}" /mnt
mount -o ${BTRFS_OPTS},subvol=@home "${ROOT_PART}" /mnt/home
mount -o ${BTRFS_OPTS},subvol=@var_log "${ROOT_PART}" /mnt/var/log
```

**Mount Options Explained:**

| Option | Purpose | Benefit |
|--------|---------|---------|
| `noatime` | Don't update access time | Reduces writes, improves SSD lifespan |
| `compress=zstd:1` | Transparent compression (level 1) | Saves space, fast compression |
| `space_cache=v2` | Modern free space cache | Faster mount times, better performance |
| `commit=120` | Commit data every 120 seconds | Balance between safety and performance |
| `discard=async` | Asynchronous TRIM for SSDs | Better SSD performance and lifespan |

**Why these options?**

- **Performance**: Reduced write operations, faster operations
- **SSD Longevity**: Proper TRIM support, reduced wear
- **Space Efficiency**: Transparent compression saves disk space
- **Modern Best Practices**: Using latest btrfs features

### UEFI Boot Partition Mount

```bash
mount -o fmask=0077,dmask=0077 "${BOOT_PART}" /mnt/boot
```

**Security Options:**

| Option | Effect | Purpose |
|--------|--------|---------|
| `fmask=0077` | File permissions: 600 (rw-------) | Only root can read/write files |
| `dmask=0077` | Directory permissions: 700 (rwx------) | Only root can access directories |

**Why restrict permissions?**
- **Security**: Prevents unauthorized access to kernel images
- **Protection**: Bootloader files should only be modified by root
- **Best Practice**: Minimizes attack surface

---

## Complete Mount Structure

### UEFI with btrfs
```
/mnt                    (@ subvolume)
├── /home              (@home subvolume)
├── /var/log           (@var_log subvolume)
└── /boot              (ESP - FAT32, restricted permissions)
```

### UEFI with ext4
```
/mnt                    (ext4 partition)
└── /boot              (ESP - FAT32, restricted permissions)
```

### BIOS with btrfs
```
/mnt                    (@ subvolume)
├── /home              (@home subvolume)
├── /var/log           (@var_log subvolume)
└── /boot              (directory within @)
```

### BIOS with ext4
```
/mnt                    (ext4 partition)
└── /boot              (directory within root)
```

---

## Summary Flow

```
1. WIPE DISK
   ├─ wipefs: Remove all signatures
   └─ sgdisk: Destroy partition tables

2. CREATE PARTITIONS
   ├─ UEFI: GPT with ESP (512MB) + Root
   └─ BIOS: MBR with single Root partition

3. FORMAT PARTITIONS
   ├─ Boot (UEFI only): FAT32
   └─ Root: btrfs or ext4

4. SETUP BTRFS (if selected)
   ├─ Create subvolumes (@, @home, @var_log)
   └─ Unmount for proper remounting

5. MOUNT FILESYSTEMS
   ├─ Mount root with optimal options
   ├─ Mount subvolumes (btrfs only)
   └─ Mount boot with security restrictions (UEFI only)

6. READY FOR INSTALLATION
   └─ /mnt is now prepared for pacstrap
```

---

## Key Design Decisions

### 1. **Separate Subvolumes**
- Enables selective snapshots
- Protects user data during system rollback
- Prevents log bloat in snapshots

### 2. **Optimal Mount Options**
- Balances performance, durability, and space
- SSD-optimized with async discard
- Compression for space savings

### 3. **Security-First Boot**
- Restricted permissions on ESP
- Prevents unauthorized bootloader modification
- Follows security best practices

### 4. **Flexible Architecture**
- Supports UEFI and BIOS
- Supports btrfs and ext4
- Handles different disk types (SATA, NVMe, Virtual)

### 5. **Timeshift Integration**
- Subvolume structure follows Timeshift conventions
- Enables easy system snapshots and rollback
- Protects against failed updates

---

## Troubleshooting

### Issue: "partition overlaps with partition table"
**Solution:** Ensure `wipefs` and `sgdisk --zap-all` run successfully

### Issue: NVMe partition not found
**Solution:** Script automatically handles `p` prefix for NVMe devices

### Issue: Boot partition too small
**Solution:** 512MiB is standard and sufficient for multiple kernels

### Issue: Btrfs compression not working
**Solution:** Verify mount options include `compress=zstd:1`

### Issue: ESP permission errors after install
**Solution:** `fmask=0077,dmask=0077` ensures proper security

---

## References

- [Arch Wiki: Partitioning](https://wiki.archlinux.org/title/Partitioning)
- [Arch Wiki: Btrfs](https://wiki.archlinux.org/title/Btrfs)
- [Arch Wiki: EFI System Partition](https://wiki.archlinux.org/title/EFI_system_partition)
- [UEFI Specification](https://uefi.org/specifications)
- [Btrfs Documentation](https://btrfs.wiki.kernel.org/)
