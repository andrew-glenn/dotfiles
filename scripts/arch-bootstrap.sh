#!/usr/bin/env bash
#
# arch-bootstrap.sh
# Run this from the Arch Linux live ISO environment (as root).
#
# Does:
#   - Destructively partitions a chosen disk
#   - ext4 root (+ ESP if UEFI), auto-detected boot mode, GRUB
#   - i3 minimal WM, zram swap, NetworkManager
#   - Prompts for hostname / user / password / timezone / locale
#
# Does NOT:
#   - Handle dual boot, LUKS encryption, RAID, or multi-disk layouts
#
set -euo pipefail

# ---------- helpers ----------

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31m!!\033[0m %s\n' "$1" >&2; exit 1; }

ask() {
  local prompt="$1" default="${2:-}" reply
  read -rp "${prompt}${default:+ [$default]}: " reply
  echo "${reply:-$default}"
}

# Return the Nth partition device path for a given disk.
# nvme/mmc devices use a 'p' separator (e.g. /dev/nvme0n1p1), others don't.
part_dev() {
  local disk="$1" num="$2"
  if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

# ---------- pre-flight checks ----------

[[ $EUID -eq 0 ]] || die "Run this as root from the Arch ISO."

if [[ -d /sys/firmware/efi/efivars ]]; then
  BOOT_MODE="uefi"
else
  BOOT_MODE="bios"
fi
log "Detected boot mode: $BOOT_MODE"

ping -c1 -W2 archlinux.org &>/dev/null \
  || die "No network connectivity. Connect first (iwctl / dhcpcd) and retry."

timedatectl set-ntp true

# ---------- gather input ----------

log "Available block devices:"
lsblk -dpno NAME,SIZE,MODEL | grep -v loop

TARGET_DISK=$(ask "Target disk (e.g. /dev/sda or /dev/nvme0n1)")
[[ -b "$TARGET_DISK" ]] || die "No such block device: $TARGET_DISK"

echo
echo "!! WARNING !! This will ERASE ALL DATA on $TARGET_DISK"
CONFIRM=$(ask "Type the disk path again to confirm")
[[ "$CONFIRM" == "$TARGET_DISK" ]] || die "Confirmation did not match. Aborting."

HOSTNAME=$(ask "Hostname" "archbox")
USERNAME=$(ask "Username to create" "arch")

while true; do
  read -rsp "Password for $USERNAME (and root): " PASSWORD; echo
  read -rsp "Confirm password: " PASSWORD2; echo
  [[ "$PASSWORD" == "$PASSWORD2" && -n "$PASSWORD" ]] && break
  echo "Passwords didn't match or were empty, try again."
done

TIMEZONE=$(ask "Timezone" "UTC")
LOCALE=$(ask "Locale" "en_US.UTF-8")
KEYMAP=$(ask "Console keymap" "us")

# ---------- partitioning ----------

log "Partitioning $TARGET_DISK for $BOOT_MODE boot..."

wipefs -af "$TARGET_DISK"

if [[ "$BOOT_MODE" == "uefi" ]]; then
  parted -s "$TARGET_DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%
  ESP_PART=$(part_dev "$TARGET_DISK" 1)
  ROOT_PART=$(part_dev "$TARGET_DISK" 2)
else
  parted -s "$TARGET_DISK" \
    mklabel msdos \
    mkpart primary ext4 1MiB 100% \
    set 1 boot on
  ROOT_PART=$(part_dev "$TARGET_DISK" 1)
fi

partprobe "$TARGET_DISK"
sleep 2  # let the kernel finish re-reading the partition table

# ---------- formatting ----------

log "Formatting..."
mkfs.ext4 -F "$ROOT_PART"
mount "$ROOT_PART" /mnt

if [[ "$BOOT_MODE" == "uefi" ]]; then
  mkfs.fat -F32 "$ESP_PART"
  mkdir -p /mnt/boot
  mount "$ESP_PART" /mnt/boot
fi

# ---------- base install ----------

log "Installing base system (this takes a while)..."
PACKAGES=(
  base base-devel linux linux-firmware
  networkmanager
  sudo vim git curl
  grub
  xorg-server xorg-xinit
  i3-wm i3status i3lock dmenu
  alacritty
  zram-generator
)
[[ "$BOOT_MODE" == "uefi" ]] && PACKAGES+=(efibootmgr)

pacstrap -K /mnt "${PACKAGES[@]}"

log "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ---------- chroot configuration ----------

# Write the password to a temporary file so the heredoc can be single-quoted
# (no risk of shell metacharacters in the password breaking expansion).
PASS_FILE=/mnt/root/.install-pw
printf '%s' "$PASSWORD" > "$PASS_FILE"
chmod 600 "$PASS_FILE"

log "Entering chroot..."

# Single-quoted heredoc delimiter prevents variable expansion — all values are
# passed as explicit environment variables via arch-chroot's env.
arch-chroot /mnt /usr/bin/env \
  TIMEZONE="$TIMEZONE" \
  LOCALE="$LOCALE" \
  KEYMAP="$KEYMAP" \
  HOSTNAME_="$HOSTNAME" \
  USERNAME="$USERNAME" \
  BOOT_MODE="$BOOT_MODE" \
  TARGET_DISK="$TARGET_DISK" \
  bash -s <<'CHROOT_EOF'
set -euo pipefail

# -- timezone / clock --
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# -- locale --
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# -- hostname / hosts --
echo "${HOSTNAME_}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME_}.localdomain ${HOSTNAME_}
EOF

# -- users --
PW=$(cat /root/.install-pw)
echo "root:${PW}" | chpasswd
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${PW}" | chpasswd
rm -f /root/.install-pw
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# -- bootloader --
if [[ "${BOOT_MODE}" == "uefi" ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install --target=i386-pc "${TARGET_DISK}"
fi
grub-mkconfig -o /boot/grub/grub.cfg

# -- zram swap (no swap partition/file) --
cat > /etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
ZRAM

# -- services --
systemctl enable NetworkManager

# -- minimal .xinitrc so 'startx' launches i3 --
cat > "/home/${USERNAME}/.xinitrc" <<XINIT
exec i3
XINIT
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.xinitrc"
CHROOT_EOF

# Clean up in case chroot failed before removing it
rm -f /mnt/root/.install-pw

log "Done. Unmount and reboot when ready:"
echo "    umount -R /mnt"
echo "    reboot"
echo
echo "After first login, run 'startx' to launch i3."
